import UnityEngine
import clojure.lang
#import ucccore

class ClojureTest (MonoBehaviour):
  private input_rect as Rect
  private input_buf = ""
  private log_rect as Rect
  private log_buf = ""
  private logs = []
  private logs_max as int = 1
  private ready_clojure = false
  private guiSkin as GUISkin
  private event_done = false
  private old_screen = Vector2(0, 0)

  private myeval_fn as IFn
  private pr_str as IFn

  static private current_obj as ClojureTest

  # TODO: 余裕があれば、input欄の横にclear/submitボタンもつける

  private def update_log_buf():
    log_buf = logs.Join("\n")

  private def append_log(line as string):
    # TODO: 古いログを消さずに、単に追記と、
    #       カーソル位置をtextarea末尾に移動させるだけにさせたいが、
    #       textarea内でのカーソル位置をいじる事はできないっぽい…
    lines = @/\n/.Split(line)
    logs.Extend(lines)
    while logs_max < len(logs):
      logs.RemoveAt(0)
    update_log_buf()

  private def refresh_input():
    w as int = Screen.width - 8 - 8
    h as int = 21 # NB: Depnd on font size and style
    x as int = 8
    y as int = Screen.height - 8 - h
    input_rect = Rect(x, y, w, h)

  private def refresh_log():
    w as int = Screen.width - 8 - 8
    h as int = Screen.height - 8 - 8 - input_rect.height - 8
    x as int = 8
    y as int = 8
    log_rect = Rect(x, y, w, h)

  private def reset_logs_max():
    # TODO: 柔軟に設定できるようにする事
    line_height = 16 # NB: Depnd on font size and style
    logs_max = log_rect.height / line_height
    #logs_max = 999 # for debug
    #logs = [] # TODO: 空改行で初期化する？しない？
    #update_log_buf()

  private def clojure_init():
    myeval_script = """
    ;; TODO: eval実行後の *ns* をどこかに記録しておき、再利用できるようにする
    (fn [source]
      (binding [*ns* *ns*
                *warn-on-reflection* *warn-on-reflection*
                *math-context* *math-context*
                *print-meta* *print-meta*
                *print-length* *print-length*
                *print-level* *print-level*
                *data-readers* *data-readers*
                *default-data-reader-fn* *default-data-reader-fn*
                *compile-path* "."
                *command-line-args* *command-line-args*
                *unchecked-math* *unchecked-math*
                *assert* *assert*
                *1 nil
                *2 nil
                *3 nil
                *e nil]
        (in-ns 'user)
        (eval (read-string source))
        ;; TODO: 多値対応させたい。しかし受け側にも対応が必要なのでめんどい。
        ;;       しかしコピペで複数行貼ると多値入力扱いになるので必須！
        ;;       どうにかする事。
        ;(with-in-str source
        ;  (loop [acc []]
        ;    (let [ie (read *in* false ::eof)]
        ;      (if (= ie ::eof)
        ;        acc
        ;        (recur (conj acc (eval ie)))))))
        ))
    """
    read_string as IFn = RT.var('clojure.core', 'read-string')
    eval as IFn = RT.var('clojure.core', 'eval')
    myeval_ie = read_string.invoke(myeval_script)
    myeval_fn = eval.invoke(myeval_ie)
    pr_str = RT.var('clojure.core', 'pr-str')

  private def readeval(edn as string):
    return myeval_fn.invoke(edn)

  #def Awake():
  #  pass

  def refresh_screen():
    refresh_input()
    refresh_log()
    reset_logs_max()
    old_screen.x = Screen.width
    old_screen.y = Screen.height

  def Start():
    guiSkin = Resources.Load("skin", typeof(GUISkin))
    refresh_screen()
    current_obj = self

    # Clojure init
    try:
      clojure_init()
      ready_clojure = true
      append_log("*** ClojureCLR REPL on Unity - test ***")
      append_log("ClojureCLR-" + readeval("(clojure-version)"))
      append_log("使い方：")
      append_log("下欄にClojure式を入力してリターンキーを押すと評価されます。")
      append_log("(一行で入力する必要があります。)")
      append_log("※現在のところ、多値入力に対応していません。")
      append_log("※現在のところ、 *ns* を user 以外に変更できません。")
      append_log("※現在のところ、ヒストリ補完機能がありません。")
      append_log("　上欄からコピペする事は一応可能です。")
      append_log("※長い行は、上欄内にてカーソル移動させて見る事ができます。")
      append_log("　(分かりづらくてすいません。)")
      append_log("背景のオブジェクトは以下のような感じでいじれます。")
      append_log("(import 'CubeRotator)")
      append_log("(def ^CubeRotator cube-rotator (.. GameObject (Find \"CubeRotator\") (GetComponent \"CubeRotator\")))")
      append_log("(set! (.rotateSpeed cube-rotator) (Vector3. 10 10 10))")
    except e:
      append_log(e.ToString())

  # (import 'ClojureTest) してから
  # (ClojureTest/Test) で実行できる。
  # これを応用して、なんか3Dオブジェクトをうごかすデモを用意する
  # (直にUnityEngineモジュールを叩いたりする)
  # どういうのがいいか考えておく事。
  static public def Test():
    current_obj.append_log("testtesttest")

  def Update():
    event_done = false

  def OnGUI():
    if old_screen.x != Screen.width or old_screen.y != Screen.height:
      refresh_screen()
    GUI.skin = guiSkin
    GUI.SetNextControlName ("input")
    new_buf = GUI.TextField(input_rect, input_buf)
    # input_bufにコピペで改行コード等が含まれないようにする
    input_buf = new_buf.Replace("\r", " ").Replace("\n", " ")
    # TODO: ↑↓キーでのヒストリ呼び出しもほしい
    if not event_done and Event.current.isKey and Event.current.keyCode == KeyCode.Return:
      append_log("> " + input_buf)
      if input_buf != "":
        try:
          result = readeval(input_buf)
          append_log(pr_str.invoke(result))
        except e:
          append_log("ERROR: " + e.ToString())
        input_buf = ""
      event_done = true
    GUI.TextArea(log_rect, log_buf, 'box')

# vim:set fenc=utf-8 ft=boo et:
