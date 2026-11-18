import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// VPN 切换浮层 — 点一下状态栏图标，从栏下方展开面板。
//
// 数据来自 ~/.local/bin/vpn-switch panel（JSON）。列表会自动发现本机安装的
// VPN / 代理，点条目调用 vpn-switch toggle <id>，可同时开启互不冲突的多个
// provider；冲突行会标出原因，点下去会被脚本拒绝。面板的点击外部关闭、定位、
// 描边都由 PopupCard 负责。
BarWidget {
  id: root
  moduleName: "io.github.shawnicsc.vpn"

  property bool opened: false
  property var state: ({ "current": "off", "active": [], "changedAt": 0, "providers": [] })
  property int tick: 0

  readonly property string current: String(state.current || "off")
  readonly property bool connected: root.current !== "off"
  readonly property int activeCount: (state.active || []).length
  readonly property string headline: root.activeCount > 1 ? ("VPN · " + root.activeCount + " 个连接") : "VPN"

  // 插件安装时脚本在 bin/vpn-switch；旧式自定义模块安装时脚本在 PATH。
  property bool bundledScriptMissing: false
  readonly property string scriptPath: {
    if (root.bundledScriptMissing) return "vpn-switch"
    var s = Qt.resolvedUrl("bin/vpn-switch").toString()
    if (s.indexOf("file://") === 0) s = decodeURIComponent(s.slice(7))
    return s
  }

  FileView {
    id: scriptProbe
    path: Qt.resolvedUrl("bin/vpn-switch")
    blockLoading: true
    printErrors: false
    onLoaded: root.bundledScriptMissing = false
    onLoadFailed: root.bundledScriptMissing = true
  }

  function runScript(args) {
    actionProc.command = [root.scriptPath].concat(args)
    actionProc.running = true
  }

  // Nerd Font（Material Design Icons）里的盾牌：连上 = 实心 + 对勾，断开 = 空心。
  // 之前这里是 "\uF0562"，JS 的 \u 转义只吃 4 位十六进制，实际画成了私用区
  // 的 U+F056 加一个字面 "2"，所以状态栏上一直是个认不出的杂字形。
  readonly property string glyph: root.connected ? "󰕥" : "󰒙"
  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Commons.Color.muted
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: Commons.Color.urgent
  readonly property string mono: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false

  // ---- 数据 ----
  readonly property var rows: {
    var out = []
    var p = state.providers || []
    for (var i = 0; i < p.length; i++) out.push(p[i])
    out.push({ "id": "off", "label": "全部断开", "hint": "释放路由 / DNS", "on": root.activeCount === 0 })
    return out
  }

  function applyJson(text) {
    try {
      var d = JSON.parse(String(text))
      if (d && d.providers) state = d
    } catch (e) {
      // 解析失败就保留上一次的数据
    }
  }

  function refresh() {
    if (!panelProc.running) panelProc.running = true
  }

  function agoText() {
    var t = Number(state.changedAt || 0)
    if (!t) return "本次会话还没切过"
    var s = Math.max(0, Math.floor(Date.now() / 1000) - t)
    if (s < 60) return s + " 秒前切换"
    if (s < 3600) return Math.floor(s / 60) + " 分钟前切换"
    if (s < 86400) return Math.floor(s / 3600) + " 小时前切换"
    return Math.floor(s / 86400) + " 天前切换"
  }

  function titleOf(id) {
    for (var i = 0; i < rows.length; i++) if (rows[i].id === id) return rows[i].label
    return id
  }

  function activate(id) {
    opened = false
    if (String(id) === "off") runScript(["off"])
    else runScript(["toggle", String(id)])
    settle.restart()
  }

  function open() { opened = true; refresh() }
  function close() { opened = false }
  function toggle() { if (opened) close(); else open() }

  // 面板作为 popout 的身份：让状态栏画那条"面板已展开"的下划线，
  // 并和其它面板互斥。
  readonly property bool popoutSwitchClosing: false
  function closeForPopoutSwitch() { root.close() }

  // 和其它栏图标同一套节奏：iconSlot 宽、iconCanvas 大的光学画布，
  // 这样不会被自己的行宽挤成和邻居不一样的间距。
  implicitWidth: root.vertical ? (bar ? bar.barSize : Style.bar.sizeVertical) : Style.bar.iconSlot
  implicitHeight: root.vertical ? Style.bar.iconSlot : (bar ? bar.barSize : Style.bar.sizeHorizontal)

  // ---- 状态栏上的图标 ----
  Item {
    anchors.centerIn: parent
    width: Style.bar.iconCanvas
    height: Style.bar.iconCanvas

    OpticalGlyph {
      anchors.fill: parent
      text: root.glyph
      fontFamily: root.mono
      fontSize: Style.bar.iconFont
      color: root.connected ? root.fg : root.dim
    }
  }

  // 状态栏的点击不经过 MouseArea：Bar 自己命中 activeItem，然后调用它的
  // triggerPress(button)。鼠标和触控板走的是同一条路径，所以这里实现这个名字。
  function triggerPress(button) {
    if (button === undefined || button === Qt.LeftButton) root.toggle()
  }

  IpcHandler {
    target: "vpn"

    function toggle(): void { root.toggle() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function refresh(): void { root.refresh() }
  }

  // ---- 弹层 ----
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.opened
    contentWidth: fittedContentWidth(Style.space(252))
    contentHeight: fittedContentHeight(body.implicitHeight)

    Column {
      id: body
      anchors.fill: parent
      spacing: Style.space(2)

      // 标题行
      Item {
        width: parent.width
        implicitHeight: Style.space(18)

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root.headline
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.mono
          font.pixelSize: Style.font.caption
          font.letterSpacing: Style.space(1)
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: { root.tick; return root.agoText() }
          color: root.dim
          font.family: root.mono
          font.pixelSize: Style.font.caption
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: root.dim
        opacity: 0.22
      }

      // 四个条目
      Repeater {
        model: root.rows

        delegate: Rectangle {
          id: rowItem
          width: body.width
          height: Style.space(28)
          radius: Style.space(5)
          color: rowHover.hovered
            ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10)
            : "transparent"

          HoverHandler {
            id: rowHover
            cursorShape: Qt.PointingHandCursor
          }

          MouseArea {
            anchors.fill: parent
            onClicked: root.activate(modelData.id)
          }

          Rectangle {
            id: dot
            width: Style.space(7)
            height: Style.space(7)
            radius: width / 2
            anchors.left: parent.left
            anchors.leftMargin: Style.space(3)
            anchors.verticalCenter: parent.verticalCenter
            color: modelData.conflicts && modelData.conflicts.length > 0
              ? root.urgent
              : (modelData.on ? root.accent : root.dim)
            opacity: modelData.on || (modelData.conflicts && modelData.conflicts.length > 0) ? 1.0 : 0.40
          }

          Text {
            id: hint
            anchors.right: parent.right
            anchors.rightMargin: Style.space(3)
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.conflicts && modelData.conflicts.length > 0
              ? "冲突: " + modelData.conflicts.join("、")
              : (modelData.on
                  ? "已连接"
                  : (modelData.manageable === false ? "仅检测" : (modelData.hint || "")))
            textFormat: Text.PlainText
            color: modelData.conflicts && modelData.conflicts.length > 0
              ? root.urgent
              : (modelData.on ? root.accent : root.dim)
            opacity: modelData.on || (modelData.conflicts && modelData.conflicts.length > 0) ? 1.0 : 0.75
            font.family: root.mono
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.left: dot.right
            anchors.leftMargin: Style.space(9)
            anchors.right: hint.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            textFormat: Text.PlainText
            color: root.fg
            opacity: modelData.on ? 1.0 : 0.72
            elide: Text.ElideRight
            font.family: root.mono
            font.pixelSize: Style.font.body
          }
        }
      }

      // 底部提示
      Item {
        width: parent.width
        implicitHeight: Style.space(16)

        Text {
          anchors.centerIn: parent
          text: root.activeCount > 1
            ? ("已连接 " + root.activeCount + " 个 · 点条目开关")
            : ("当前：" + root.titleOf(root.current) + " · 点条目开关")
          textFormat: Text.PlainText
          color: root.dim
          opacity: 0.8
          font.family: root.mono
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  Process {
    id: panelProc
    command: [root.scriptPath, "panel"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyJson(text)
    }
  }

  Process {
    id: actionProc
    command: []
  }

  // 常态轮询：让状态栏上的圆点跟得上（比如在客户端里手动连/断）
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // 切完之后立刻刷新一次
  Timer {
    id: settle
    interval: 1200
    repeat: false
    onTriggered: root.refresh()
  }

  // 面板开着时每分钟刷新"多久之前"
  Timer {
    interval: 60000
    running: root.opened
    repeat: true
    onTriggered: root.tick = root.tick + 1
  }
}
