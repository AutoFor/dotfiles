using System; // 基本的なシステム機能を使用
using System.Collections.Generic; // リストやディクショナリを使用
using System.Diagnostics; // スタックトレース取得用
using System.IO; // ファイル入出力用
using System.Runtime.CompilerServices; // 呼び出し元情報の自動取得用
using System.Text; // 文字列操作用
using System.Threading; // スレッド情報取得用

namespace SpotifyAutoPlayer // このアプリケーションの名前空間
{
    // 概要: デバッグ用の強力なロガークラス
    // サブ概要: ログレベル、ファイル出力、コンソール表示、スタックトレースなど豊富な機能を提供
    public class DebugLogger
    {
        // ログレベルの定義
        public enum LogLevel
        {
            TRACE = 0,   // 最も詳細な情報（関数の入出など）
            DEBUG = 1,   // デバッグ情報（変数の値など）
            INFO = 2,    // 通常の情報（処理の進行状況など）
            WARN = 3,    // 警告（問題になる可能性がある状態）
            ERROR = 4,   // エラー（回復可能な問題）
            FATAL = 5    // 致命的エラー（回復不可能な問題）
        }

        // プロパティ
        private static readonly object _lockObject = new object(); // スレッドセーフ用のロックオブジェクト
        private static DebugLogger? _instance; // シングルトンインスタンス（null許容）
        private LogLevel _currentLogLevel = LogLevel.DEBUG; // 現在のログレベル（これ以上のレベルのみ出力）
        private string? _logFilePath; // ログファイルのパス（null許容）
        private bool _enableConsole = true; // コンソール出力を有効にするか
        private bool _enableFile = true; // ファイル出力を有効にするか
        private bool _includeStackTrace = false; // スタックトレースを含めるか
        private int _maxFileSize = 10 * 1024 * 1024; // ログファイルの最大サイズ（10MB）
        private Dictionary<string, DateTime> _performanceTimers = new Dictionary<string, DateTime>(); // パフォーマンス測定用タイマー

        // 概要: シングルトンインスタンスを取得
        public static DebugLogger Instance
        {
            get
            {
                if (_instance == null) // インスタンスがまだ作成されていない場合
                {
                    lock (_lockObject) // スレッドセーフにするためロック
                    {
                        if (_instance == null) // ダブルチェック
                        {
                            _instance = new DebugLogger(); // 新しいインスタンスを作成
                        }
                    }
                }
                return _instance; // インスタンスを返す
            }
        }

        // 概要: コンストラクタ（プライベート、シングルトンパターン）
        private DebugLogger()
        {
            // 初期状態ではファイルパスは設定しない（遅延初期化）
            // EnableFile(true)が呼ばれたときに初めてファイルパスを設定
        }

        // 概要: ログレベルを設定
        public void SetLogLevel(LogLevel level)
        {
            _currentLogLevel = level; // ログレベルを更新
            Info($"ログレベルを {level} に設定しました"); // 設定変更をログに記録
        }

        // 概要: コンソール出力の有効/無効を設定
        public void EnableConsole(bool enable)
        {
            _enableConsole = enable; // フラグを更新
        }

        // 概要: ファイル出力の有効/無効を設定
        public void EnableFile(bool enable)
        {
            _enableFile = enable; // フラグを更新
            
            // ファイル出力を有効にする場合、まだパスが設定されていなければ設定
            if (enable && string.IsNullOrEmpty(_logFilePath)) // ファイル出力を有効化かつパス未設定の場合
            {
                InitializeLogFile(); // ログファイルを初期化
            }
        }
        
        // 概要: ログファイルパスを初期化
        private void InitializeLogFile()
        {
            // ログファイルのパスを設定（プロジェクトルート直下のlogフォルダ）
            string exePath = AppDomain.CurrentDomain.BaseDirectory; // 実行ファイルのディレクトリを取得
            
            // bin\Debug\net8.0からプロジェクトルートに戻る
            DirectoryInfo? dirInfo = new DirectoryInfo(exePath); // ディレクトリ情報を取得
            while (dirInfo != null && dirInfo.Name != "spotifyAutoPlayer") // プロジェクトルートまで遡る
            {
                dirInfo = dirInfo.Parent; // 親ディレクトリに移動（nullの可能性あり）
            }
            
            // プロジェクトルート直下のlogフォルダを設定
            string rootPath = dirInfo != null ? dirInfo.FullName : exePath; // ルートパスを決定
            string logDir = Path.Combine(rootPath, "log"); // logフォルダのパスを作成
            
            if (!Directory.Exists(logDir)) // logフォルダが存在しない場合
            {
                Directory.CreateDirectory(logDir); // ディレクトリを作成
            }

            // 日付時刻を含むログファイル名を生成
            string fileName = $"debug_{DateTime.Now:yyyyMMdd_HHmmss}.log"; // ファイル名を生成
            _logFilePath = Path.Combine(logDir, fileName); // フルパスを作成
        }

        // 概要: スタックトレースの有効/無効を設定
        public void EnableStackTrace(bool enable)
        {
            _includeStackTrace = enable; // フラグを更新
        }

        // 概要: TRACEレベルのログを出力
        public void Trace(string message,
            [CallerMemberName] string memberName = "", // 呼び出し元のメソッド名を自動取得
            [CallerFilePath] string sourceFilePath = "", // 呼び出し元のファイルパスを自動取得
            [CallerLineNumber] int sourceLineNumber = 0) // 呼び出し元の行番号を自動取得
        {
            Log(LogLevel.TRACE, message, memberName, sourceFilePath, sourceLineNumber); // ログ出力メソッドを呼び出し
        }

        // 概要: DEBUGレベルのログを出力
        public void Debug(string message,
            [CallerMemberName] string memberName = "",
            [CallerFilePath] string sourceFilePath = "",
            [CallerLineNumber] int sourceLineNumber = 0)
        {
            Log(LogLevel.DEBUG, message, memberName, sourceFilePath, sourceLineNumber); // ログ出力メソッドを呼び出し
        }

        // 概要: INFOレベルのログを出力
        public void Info(string message,
            [CallerMemberName] string memberName = "",
            [CallerFilePath] string sourceFilePath = "",
            [CallerLineNumber] int sourceLineNumber = 0)
        {
            Log(LogLevel.INFO, message, memberName, sourceFilePath, sourceLineNumber); // ログ出力メソッドを呼び出し
        }

        // 概要: WARNレベルのログを出力
        public void Warn(string message,
            [CallerMemberName] string memberName = "",
            [CallerFilePath] string sourceFilePath = "",
            [CallerLineNumber] int sourceLineNumber = 0)
        {
            Log(LogLevel.WARN, message, memberName, sourceFilePath, sourceLineNumber); // ログ出力メソッドを呼び出し
        }

        // 概要: ERRORレベルのログを出力
        public void Error(string message, Exception? ex = null,
            [CallerMemberName] string memberName = "",
            [CallerFilePath] string sourceFilePath = "",
            [CallerLineNumber] int sourceLineNumber = 0)
        {
            string fullMessage = message; // メッセージを初期化
            if (ex != null) // 例外オブジェクトが提供された場合
            {
                fullMessage += $"\n例外: {ex.GetType().Name}: {ex.Message}"; // 例外情報を追加
                fullMessage += $"\nスタックトレース:\n{ex.StackTrace}"; // スタックトレースを追加
            }
            Log(LogLevel.ERROR, fullMessage, memberName, sourceFilePath, sourceLineNumber); // ログ出力メソッドを呼び出し
        }

        // 概要: FATALレベルのログを出力
        public void Fatal(string message, Exception? ex = null,
            [CallerMemberName] string memberName = "",
            [CallerFilePath] string sourceFilePath = "",
            [CallerLineNumber] int sourceLineNumber = 0)
        {
            string fullMessage = message; // メッセージを初期化
            if (ex != null) // 例外オブジェクトが提供された場合
            {
                fullMessage += $"\n致命的例外: {ex.GetType().Name}: {ex.Message}"; // 例外情報を追加
                fullMessage += $"\nスタックトレース:\n{ex.StackTrace}"; // スタックトレースを追加
            }
            Log(LogLevel.FATAL, fullMessage, memberName, sourceFilePath, sourceLineNumber); // ログ出力メソッドを呼び出し
        }

        // 概要: パフォーマンス測定を開始
        public void StartTimer(string timerName)
        {
            lock (_lockObject) // スレッドセーフにするためロック
            {
                _performanceTimers[timerName] = DateTime.Now; // 現在時刻を記録
                Debug($"パフォーマンス測定開始: {timerName}"); // デバッグログを出力
            }
        }

        // 概要: パフォーマンス測定を終了
        public void StopTimer(string timerName)
        {
            lock (_lockObject) // スレッドセーフにするためロック
            {
                if (_performanceTimers.ContainsKey(timerName)) // タイマーが存在する場合
                {
                    TimeSpan elapsed = DateTime.Now - _performanceTimers[timerName]; // 経過時間を計算
                    Info($"パフォーマンス測定終了: {timerName} - 経過時間: {elapsed.TotalMilliseconds:F2}ms"); // 結果をログ出力
                    _performanceTimers.Remove(timerName); // タイマーを削除
                }
                else
                {
                    Warn($"タイマー '{timerName}' が見つかりません"); // 警告を出力
                }
            }
        }

        // 概要: オブジェクトの詳細をダンプ
        public void DumpObject(object obj, string objectName = "Object")
        {
            if (obj == null) // オブジェクトがnullの場合
            {
                Debug($"{objectName} = null"); // nullと出力
                return; // 処理を終了
            }

            Type type = obj.GetType(); // オブジェクトの型を取得
            StringBuilder sb = new StringBuilder(); // 文字列を構築するためのStringBuilder
            sb.AppendLine($"=== {objectName} ダンプ ==="); // ヘッダーを追加
            sb.AppendLine($"型: {type.FullName}"); // 型名を追加

            // プロパティ情報を取得
            foreach (var prop in type.GetProperties()) // すべてのプロパティを走査
            {
                try
                {
                    var value = prop.GetValue(obj); // プロパティの値を取得
                    sb.AppendLine($"  {prop.Name}: {value ?? "null"}"); // プロパティ名と値を追加
                }
                catch (Exception ex) // エラーが発生した場合
                {
                    sb.AppendLine($"  {prop.Name}: [エラー: {ex.Message}]"); // エラーメッセージを追加
                }
            }

            Debug(sb.ToString()); // デバッグログとして出力
        }

        // 概要: メモリ使用状況をログ出力
        public void LogMemoryUsage(string context = "")
        {
            long memoryUsed = GC.GetTotalMemory(false) / 1024 / 1024; // 使用メモリをMB単位で取得
            string message = string.IsNullOrEmpty(context) ? // コンテキストが指定されているか確認
                $"メモリ使用量: {memoryUsed} MB" : // コンテキストなし
                $"メモリ使用量 ({context}): {memoryUsed} MB"; // コンテキストあり
            Info(message); // 情報ログとして出力
        }

        // 概要: 区切り線を出力
        public void LogSeparator(string title = "")
        {
            string separator = string.IsNullOrEmpty(title) ? // タイトルが指定されているか確認
                "=" .PadRight(80, '=') : // タイトルなし
                $"===== {title} ".PadRight(80, '='); // タイトルあり
            Info(separator); // 情報ログとして出力
        }

        // 概要: メインのログ出力メソッド（内部使用）
        private void Log(LogLevel level, string message, string memberName, string sourceFilePath, int sourceLineNumber)
        {
            if (level < _currentLogLevel) // 現在のログレベルより低い場合
            {
                return; // 出力しない
            }

            lock (_lockObject) // スレッドセーフにするためロック
            {
                // ログメッセージを構築
                StringBuilder logMessage = new StringBuilder(); // メッセージ構築用のStringBuilder
                
                // タイムスタンプ
                logMessage.Append($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}]"); // 日時を追加
                
                // ログレベル
                logMessage.Append($"[{level,-5}]"); // ログレベルを追加（5文字幅）
                
                // スレッドID
                logMessage.Append($"[Thread:{Thread.CurrentThread.ManagedThreadId:D3}]"); // スレッドIDを追加
                
                // 呼び出し元情報
                string fileName = Path.GetFileName(sourceFilePath); // ファイル名を取得
                logMessage.Append($"[{fileName}:{sourceLineNumber}]"); // ファイル名と行番号を追加
                logMessage.Append($"[{memberName}]"); // メソッド名を追加
                
                // メッセージ本文
                logMessage.Append($" {message}"); // メッセージを追加

                // スタックトレースを含める場合
                if (_includeStackTrace && (level >= LogLevel.ERROR)) // エラー以上でスタックトレースが有効な場合
                {
                    StackTrace stackTrace = new StackTrace(true); // スタックトレースを取得
                    logMessage.AppendLine(); // 改行を追加
                    logMessage.AppendLine("スタックトレース:"); // ヘッダーを追加
                    logMessage.Append(stackTrace.ToString()); // スタックトレースを追加
                }

                string finalMessage = logMessage.ToString(); // 最終的なメッセージ

                // コンソールに出力
                if (_enableConsole) // コンソール出力が有効な場合
                {
                    ConsoleColor originalColor = Console.ForegroundColor; // 元の色を保存
                    Console.ForegroundColor = GetConsoleColor(level); // ログレベルに応じた色を設定
                    Console.WriteLine(finalMessage); // メッセージを出力
                    Console.ForegroundColor = originalColor; // 元の色に戻す
                }

                // ファイルに出力
                if (_enableFile && !string.IsNullOrEmpty(_logFilePath)) // ファイル出力が有効かつパスが設定されている場合
                {
                    try
                    {
                        // ファイルサイズチェック
                        if (File.Exists(_logFilePath)) // ファイルが存在する場合
                        {
                            FileInfo fileInfo = new FileInfo(_logFilePath); // ファイル情報を取得
                            if (fileInfo.Length > _maxFileSize) // 最大サイズを超えた場合
                            {
                                // ローテーション（古いファイルをリネーム）
                                string rotatedPath = _logFilePath.Replace(".log", $"_{DateTime.Now:yyyyMMdd_HHmmss}_rotated.log"); // 新しいファイル名
                                File.Move(_logFilePath, rotatedPath); // ファイルをリネーム
                            }
                        }

                        File.AppendAllText(_logFilePath, finalMessage + Environment.NewLine); // ファイルに追記
                    }
                    catch (Exception ex) // エラーが発生した場合
                    {
                        // ファイル出力エラーの場合はコンソールにのみ出力
                        Console.WriteLine($"ログファイル出力エラー: {ex.Message}"); // エラーメッセージを表示
                    }
                }
            }
        }

        // 概要: ログレベルに応じたコンソール色を取得
        private ConsoleColor GetConsoleColor(LogLevel level)
        {
            switch (level) // ログレベルで分岐
            {
                case LogLevel.TRACE:
                    return ConsoleColor.DarkGray; // トレースは暗い灰色
                case LogLevel.DEBUG:
                    return ConsoleColor.Gray; // デバッグは灰色
                case LogLevel.INFO:
                    return ConsoleColor.White; // 情報は白
                case LogLevel.WARN:
                    return ConsoleColor.Yellow; // 警告は黄色
                case LogLevel.ERROR:
                    return ConsoleColor.Red; // エラーは赤
                case LogLevel.FATAL:
                    return ConsoleColor.DarkRed; // 致命的エラーは暗い赤
                default:
                    return ConsoleColor.White; // デフォルトは白
            }
        }

        // 概要: ログファイルをクリア
        public void ClearLogFile()
        {
            try
            {
                if (File.Exists(_logFilePath)) // ファイルが存在する場合
                {
                    File.WriteAllText(_logFilePath, string.Empty); // 空の内容で上書き
                    Info("ログファイルをクリアしました"); // 情報ログを出力
                }
            }
            catch (Exception ex) // エラーが発生した場合
            {
                Error($"ログファイルのクリアに失敗: {ex.Message}", ex); // エラーログを出力
            }
        }

        // 概要: 現在のログファイルパスを取得
        public string? GetLogFilePath()
        {
            return _logFilePath; // ログファイルパスを返す（null許容）
        }

        // 概要: ロガーの全機能をテストする静的メソッド
        // サブ概要: 各ログレベル、タイマー、オブジェクトダンプなど全機能をテスト
        public static void RunTest()
        {
            DebugLogger logger = Instance; // ロガーインスタンスを取得
            
            Console.WriteLine(); // 空行を出力
            Console.WriteLine("==== DebugLoggerテストを開始します ===="); // テスト開始メッセージ
            Console.WriteLine(); // 空行を出力
            
            // セクション1: 基本的なログレベルのテスト
            logger.LogSeparator("ログレベルテスト"); // セクション区切り
            logger.Trace("これはTRACEレベルのメッセージです"); // 最も詳細なログ
            logger.Debug("これはDEBUGレベルのメッセージです"); // デバッグ情報
            logger.Info("これはINFOレベルのメッセージです"); // 通常情報
            logger.Warn("これはWARNレベルのメッセージです"); // 警告
            logger.Error("これはERRORレベルのメッセージです"); // エラー
            logger.Fatal("これはFATALレベルのメッセージです"); // 致命的エラー
            
            // セクション2: ログレベル変更のテスト
            logger.LogSeparator("ログレベル変更テスト"); // セクション区切り
            logger.SetLogLevel(LogLevel.WARN); // 警告レベル以上のみ出力に変更
            logger.Debug("このDEBUGメッセージは表示されません"); // 表示されない
            logger.Info("このINFOメッセージは表示されません"); // 表示されない
            logger.Warn("このWARNメッセージは表示されます"); // 表示される
            logger.SetLogLevel(LogLevel.DEBUG); // デバッグレベルに戻す
            
            // セクション3: 例外付きエラーログのテスト
            logger.LogSeparator("例外処理テスト"); // セクション区切り
            try
            {
                // 意図的に例外を発生させる
                int[] array = new int[5]; // 5要素の配列を作成
                int value = array[10]; // 範囲外アクセスで例外発生
            }
            catch (Exception ex) // 例外をキャッチ
            {
                logger.Error("配列アクセスエラーが発生しました", ex); // 例外情報付きでログ出力
            }
            
            // セクション4: パフォーマンス測定のテスト
            logger.LogSeparator("パフォーマンス測定テスト"); // セクション区切り
            logger.StartTimer("処理A"); // タイマー開始
            Thread.Sleep(100); // 100ミリ秒待機（処理をシミュレート）
            logger.StopTimer("処理A"); // タイマー終了
            
            logger.StartTimer("処理B"); // 別のタイマー開始
            Thread.Sleep(250); // 250ミリ秒待機
            logger.StopTimer("処理B"); // タイマー終了
            
            // セクション5: オブジェクトダンプのテスト
            logger.LogSeparator("オブジェクトダンプテスト"); // セクション区切り
            var testObject = new // 匿名型でテストオブジェクトを作成
            {
                Name = "テストユーザー", // 名前プロパティ
                Age = 25, // 年齢プロパティ
                Email = "test@example.com", // メールプロパティ
                IsActive = true, // アクティブフラグ
                CreatedAt = DateTime.Now // 作成日時
            };
            logger.DumpObject(testObject, "テストオブジェクト"); // オブジェクトの詳細をダンプ
            
            // セクション6: メモリ使用状況のテスト
            logger.LogSeparator("メモリ使用状況テスト"); // セクション区切り
            logger.LogMemoryUsage("テスト開始時"); // 開始時のメモリ使用量
            
            // メモリを意図的に使用
            List<string> largeList = new List<string>(); // 大きなリストを作成
            for (int i = 0; i < 10000; i++) // 10000個の要素を追加
            {
                largeList.Add($"テストデータ_{i}"); // 文字列を追加
            }
            
            logger.LogMemoryUsage("大量データ作成後"); // データ作成後のメモリ使用量
            
            // セクション7: マルチスレッドテスト
            logger.LogSeparator("マルチスレッドテスト"); // セクション区切り
            Thread thread1 = new Thread(() => // 新しいスレッドを作成
            {
                for (int i = 0; i < 3; i++) // 3回ループ
                {
                    logger.Debug($"スレッド1: メッセージ {i}"); // スレッド1からログ出力
                    Thread.Sleep(50); // 50ミリ秒待機
                }
            });
            
            Thread thread2 = new Thread(() => // 別のスレッドを作成
            {
                for (int i = 0; i < 3; i++) // 3回ループ
                {
                    logger.Debug($"スレッド2: メッセージ {i}"); // スレッド2からログ出力
                    Thread.Sleep(50); // 50ミリ秒待機
                }
            });
            
            thread1.Start(); // スレッド1開始
            thread2.Start(); // スレッド2開始
            thread1.Join(); // スレッド1の終了を待つ
            thread2.Join(); // スレッド2の終了を待つ
            
            // セクション8: ファイル出力の確認
            logger.LogSeparator("ファイル出力確認"); // セクション区切り
            string? logPath = logger.GetLogFilePath(); // ログファイルパスを取得（null許容）
            if (!string.IsNullOrEmpty(logPath)) // パスが設定されている場合
            {
                logger.Info($"ログファイルは以下に出力されています:"); // 情報ログ
                logger.Info($"  {logPath}"); // ファイルパスを表示
            }
            else
            {
                logger.Info("ログファイル出力は無効化されています"); // ファイル出力無効の通知
            }
            
            // セクション9: コンソール出力の有効/無効テスト
            logger.LogSeparator("出力設定テスト"); // セクション区切り
            logger.Info("コンソール出力を無効化します"); // 情報ログ
            logger.EnableConsole(false); // コンソール出力を無効化
            logger.Info("このメッセージはコンソールに表示されません（ファイルのみ）"); // ファイルのみに記録
            logger.EnableConsole(true); // コンソール出力を再度有効化
            logger.Info("コンソール出力を再度有効化しました"); // 情報ログ
            
            // テスト完了
            logger.LogSeparator("テスト完了"); // セクション区切り
            logger.Info("すべてのDebugLoggerテストが完了しました"); // 完了メッセージ
            logger.LogMemoryUsage("テスト終了時"); // 終了時のメモリ使用量
            
            Console.WriteLine(); // 空行を出力
            Console.WriteLine("==== テスト終了 ===="); // テスト終了メッセージ
            Console.WriteLine(); // 空行を出力
        }
    }
}