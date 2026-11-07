#!/usr/bin/env python3
"""ローカル動画を Gemini Files API へ送り、日本語の分析を Markdown に書き出す。

使い方:
    python3 analyze_video.py <動画パス> [--prompt-file FILE] [--resolution low|high]
                             [--model gemini-3.8-flash] [--out FILE] [--keep-remote]
    python3 analyze_video.py --check      # 接続確認だけ（動画は送らない）

APIキーの探索順:
    1. 環境変数 GEMINI_API_KEY
    2. ファイル ~/.gemini_api_key（1行）
    3. macOSのキーチェーン（サービス名 gemini-api-key）

標準ライブラリだけで動く。追加インストールは不要。
"""

import argparse
import json
import mimetypes
import os
import platform
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

BASE = "https://generativelanguage.googleapis.com"
DEFAULT_MODEL = "gemini-3.8-flash"
KEYCHAIN_SERVICE = "gemini-api-key"
KEY_FILE = Path.home() / ".gemini_api_key"
VIDEO_SUFFIXES = {".mp4", ".mov", ".webm", ".m4v"}
MAX_BYTES = 2 * 1024 * 1024 * 1024  # 2GB

# 料金の目安（2026年9月時点・gemini-3.8-flash）。変わることがあるので参考値として扱う。
USD_PER_M_INPUT = 0.75
USD_PER_M_OUTPUT = 3.75
JPY_PER_USD = 150.0

PROMPT_DIR = Path(__file__).resolve().parent.parent / "prompts"
DEFAULT_PROMPT_FILE = PROMPT_DIR / "reel-structure.md"

NOTES = """## 注意

- ここに書かれた秒数は概数です。編集点としてそのまま使わないでください。
- 気になった箇所は、実際の映像を自分の目で確認してください。
- Geminiが聞き取れなかった音は「不明」として扱われます。音の断定はできません。

| 項目 | Geminiの回答・時刻 | 実際の映像で確認した内容・時刻 | 採否・修正 |
|---|---|---|---|
|  |  |  |  |
"""

DEBUG = False


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def die(msg, code=1):
    log(msg)
    sys.exit(code)


def read_key_file():
    try:
        if KEY_FILE.is_file():
            value = KEY_FILE.read_text(encoding="utf-8").strip()
            if value:
                return value
    except OSError:
        return None
    return None


def read_keychain():
    if platform.system() != "Darwin":
        return None
    try:
        out = subprocess.run(
            ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
            capture_output=True, text=True, check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    value = out.stdout.strip()
    return value or None


def get_api_key():
    value = os.environ.get("GEMINI_API_KEY")
    if value and value.strip():
        return value.strip()
    value = read_key_file()
    if value:
        return value
    value = read_keychain()
    if value:
        return value
    die(
        "APIキーが見つかりません。\n"
        "セットアップガイド（setup-guide.md）の「4. キーをパソコンに置く」を見て、キーを置いてから実行してください。",
        code=2,
    )


def api_error_message(status, body):
    head = body.strip().replace("\n", " ")[:200]
    if status in (400, 401, 403):
        return ("APIキーが正しくないか、まだ有効になっていません。\n"
                "Google AI Studioでキーを作り直すか、支払い設定が済んでいるか確認してください。"
                f"（詳細 HTTP {status}: {head}）")
    if status == 429:
        return ("残高または利用上限に達しています。\n"
                "Google AI Studioの支払い設定（残高・上限）を確認してください。"
                f"（詳細 HTTP {status}: {head}）")
    return f"Geminiとの通信に失敗しました（HTTP {status}）。時間をおいて試してください。\n詳細: {head}"


def request(method, url, api_key, headers=None, data=None, timeout=600):
    """戻り値: (status, headers, body_bytes)。失敗時は日本語メッセージで終了する。"""
    hdrs = {"x-goog-api-key": api_key}
    if headers:
        hdrs.update(headers)
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, dict(resp.headers), resp.read()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        if DEBUG:
            import traceback
            traceback.print_exc()
        die(api_error_message(exc.code, body))
    except urllib.error.URLError as exc:
        if DEBUG:
            import traceback
            traceback.print_exc()
        die(f"インターネットに接続できませんでした。回線を確認してください。\n詳細: {exc.reason}")


def do_check(api_key):
    status, _, body = request("GET", f"{BASE}/v1beta/models?pageSize=1", api_key, timeout=60)
    if status == 200:
        log("接続OK：APIキーは有効です。動画の分析を実行できます。")
        return 0
    die(api_error_message(status, body.decode("utf-8", "replace")))


def probe_duration(path):
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", str(path)],
            capture_output=True, text=True, check=True,
        )
        return round(float(out.stdout.strip()), 2)
    except Exception:
        return None


def upload_video(api_key, path, mime, size):
    log(f"[1/4] 動画をアップロードしています（{size:,} バイト）")
    start_body = json.dumps({"file": {"display_name": path.name}}).encode("utf-8")
    status, headers, body = request(
        "POST", f"{BASE}/upload/v1beta/files", api_key,
        headers={
            "X-Goog-Upload-Protocol": "resumable",
            "X-Goog-Upload-Command": "start",
            "X-Goog-Upload-Header-Content-Length": str(size),
            "X-Goog-Upload-Header-Content-Type": mime,
            "Content-Type": "application/json",
        },
        data=start_body, timeout=120,
    )
    if status != 200:
        die(api_error_message(status, body.decode("utf-8", "replace")))
    upload_url = None
    for key, value in headers.items():
        if key.lower() == "x-goog-upload-url":
            upload_url = value
            break
    if not upload_url:
        die("アップロード先のURLが返りませんでした。時間をおいて試してください。")

    with path.open("rb") as fh:
        status, _, body = request(
            "POST", upload_url, api_key,
            headers={
                "Content-Length": str(size),
                "X-Goog-Upload-Offset": "0",
                "X-Goog-Upload-Command": "upload, finalize",
            },
            data=fh, timeout=1800,
        )
    if status != 200:
        die(api_error_message(status, body.decode("utf-8", "replace")))
    return json.loads(body.decode("utf-8")).get("file", {})


def wait_active(api_key, name):
    log("[2/4] Gemini側の処理を待っています")
    deadline = time.time() + 300
    while time.time() < deadline:
        status, _, body = request("GET", f"{BASE}/v1beta/{name}", api_key, timeout=60)
        if status != 200:
            die(api_error_message(status, body.decode("utf-8", "replace")))
        info = json.loads(body.decode("utf-8"))
        state = info.get("state")
        if state == "ACTIVE":
            return info
        if state == "FAILED":
            die("Gemini側で動画の処理に失敗しました。別の動画か、短く書き出した動画で試してください。")
        time.sleep(2)
    die("5分待っても動画の処理が終わりませんでした。時間をおいて試してください。")


def generate(api_key, model, file_uri, mime, prompt, resolution):
    log(f"[3/4] 分析を依頼しています（モデル {model}／解像度 {resolution}）")
    payload = {
        "contents": [{
            "role": "user",
            "parts": [
                {"file_data": {"file_uri": file_uri, "mime_type": mime}},
                {"text": prompt},
            ],
        }],
        "generationConfig": {
            "mediaResolution": "MEDIA_RESOLUTION_HIGH" if resolution == "high" else "MEDIA_RESOLUTION_LOW",
        },
    }
    status, _, body = request(
        "POST", f"{BASE}/v1beta/models/{model}:generateContent", api_key,
        headers={"Content-Type": "application/json"},
        data=json.dumps(payload).encode("utf-8"), timeout=1800,
    )
    if status != 200:
        die(api_error_message(status, body.decode("utf-8", "replace")))
    return json.loads(body.decode("utf-8"))


def extract_text(data):
    chunks = []
    for cand in data.get("candidates", []):
        for part in cand.get("content", {}).get("parts", []):
            if part.get("thought"):
                continue
            if "text" in part:
                chunks.append(part["text"])
    return "\n".join(chunks).strip()


def cost_jpy(usage):
    prompt_tokens = usage.get("promptTokenCount") or 0
    output_tokens = (usage.get("candidatesTokenCount") or 0) + (usage.get("thoughtsTokenCount") or 0)
    usd = (prompt_tokens * USD_PER_M_INPUT + output_tokens * USD_PER_M_OUTPUT) / 1_000_000.0
    return usd * JPY_PER_USD


def load_prompt(prompt_file):
    path = Path(prompt_file).expanduser() if prompt_file else DEFAULT_PROMPT_FILE
    if not path.is_file():
        die(f"分析の依頼文ファイルが見つかりません: {path}")
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        die(f"分析の依頼文ファイルが空です: {path}")
    return text


def main():
    global DEBUG
    ap = argparse.ArgumentParser(description="Geminiでローカル動画を分析する")
    ap.add_argument("video", nargs="?")
    ap.add_argument("--prompt-file")
    ap.add_argument("--resolution", choices=["low", "high"], default="low")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--out")
    ap.add_argument("--keep-remote", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--debug", action="store_true")
    args = ap.parse_args()
    DEBUG = args.debug

    api_key = get_api_key()

    if args.check:
        sys.exit(do_check(api_key))

    if not args.video:
        die("動画のパスを指定してください。例: python3 analyze_video.py ~/Desktop/reel.mp4")

    video = Path(args.video).expanduser().resolve()
    if not video.is_file():
        die(f"動画が見つかりません: {video}\nパスが正しいか確認してください。")
    if video.suffix.lower() not in VIDEO_SUFFIXES:
        die(f"この形式には対応していません（{video.suffix}）。mp4・mov・webm・m4v のどれかで渡してください。")
    size = video.stat().st_size
    if size > MAX_BYTES:
        die("動画が大きすぎます（2GBを超えています）。短く書き出してから渡してください。")

    mime = mimetypes.guess_type(video.name)[0] or "video/mp4"
    prompt = load_prompt(args.prompt_file)
    out_path = Path(args.out).expanduser() if args.out else video.with_name(video.stem + "_analysis.md")
    duration = probe_duration(video)

    uploaded = upload_video(api_key, video, mime, size)
    name = uploaded.get("name")
    if not name:
        die("アップロードの結果を読み取れませんでした。時間をおいて試してください。")
    try:
        info = wait_active(api_key, name)
        data = generate(api_key, args.model, info["uri"], mime, prompt, args.resolution)
        text = extract_text(data)
        if not text:
            die("Geminiの回答が空でした。もう一度実行してください。")
        usage = data.get("usageMetadata", {})

        log("[4/4] 結果を書き出しています")
        lines = ["---", f"model: {args.model}"]
        if duration is not None:
            lines.append(f"duration_sec: {duration}")
        lines += [
            f"size_bytes: {size}",
            f"resolution: {args.resolution}",
            f"file_uri: {info.get('uri', '')}",
            f"prompt_tokens: {usage.get('promptTokenCount', '-')}",
            f"output_tokens: {usage.get('candidatesTokenCount', '-')}",
            f"total_tokens: {usage.get('totalTokenCount', '-')}",
            f"analyzed_at: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
            "---",
            "",
            f"# 動画分析: {video.name}",
            "",
            "## Geminiの回答（原文）",
            "",
            text,
            "",
            NOTES,
        ]
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text("\n".join(lines), encoding="utf-8")
        print(str(out_path))
        total = usage.get("totalTokenCount", 0) or 0
        log(f"完了：合計 {total:,} トークン・概算 約{cost_jpy(usage):.1f}円（2026年9月時点の目安）")
    finally:
        if args.keep_remote:
            log(f"アップロードした動画はGemini側に残しました: {name}")
        else:
            try:
                req = urllib.request.Request(
                    f"{BASE}/v1beta/{name}", headers={"x-goog-api-key": api_key}, method="DELETE")
                with urllib.request.urlopen(req, timeout=60):
                    pass
                log("アップロードした動画をGemini側から削除しました")
            except Exception:
                log("アップロードした動画の削除に失敗しました（時間が経つと自動で消えます）")


if __name__ == "__main__":
    main()
