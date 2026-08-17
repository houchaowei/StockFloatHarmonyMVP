import { AlertEditorPage } from './AlertEditorPage'
import { AlertsPage } from './AlertsPage'
import { PositionEditorPage } from './PositionEditorPage'
import { PositionsPage } from './PositionsPage'
import { SettingsPage } from './SettingsPage'
import { WatchlistPage } from './WatchlistPage'

enum ManagementRoute {
  ROOT = 'root',
  ALERT_EDITOR = 'alertEditor',
  POSITION_EDITOR = 'positionEditor'
}

@Entry
@Component
struct Index {
  @StorageLink('managementRoute') managementRoute: string = ManagementRoute.ROOT
  @StorageLink('managementTab') managementTab: number = 0
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0
  @State editorSymbolId: string = ''
  @State editorAlertId: string = ''

  private openAlertEditor(symbolId: string, alertId: string): void {
    this.editorSymbolId = symbolId
    this.editorAlertId = alertId
    AppStorage.set<string>('managementRoute', ManagementRoute.ALERT_EDITOR)
  }

  private openPositionEditor(symbolId: string): void {
    this.editorSymbolId = symbolId
    AppStorage.set<string>('managementRoute', ManagementRoute.POSITION_EDITOR)
  }

  private closeEditor(): void {
    AppStorage.set<string>('managementRoute', ManagementRoute.ROOT)
  }

  @Builder
  tabBarBuilder(icon: string, label: string, index: number) {
    Column({ space: 3 }) {
      Text(icon)
        .fontSize(20)
        .fontWeight(this.managementTab === index ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.managementTab === index ? '#6F9BFF' : '#758196')
      Text(label)
        .fontSize(11)
        .fontWeight(this.managementTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.managementTab === index ? '#9DB8FF' : '#758196')
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(68 + this.bottomSafeHeight)
    .padding({ bottom: this.bottomSafeHeight })
    .accessibilityText(`${label}${this.managementTab === index ? '，已选中' : ''}`)
  }

  @Builder
  rootTabs() {
    Tabs({ barPosition: BarPosition.End, index: this.managementTab }) {
      TabContent() {
        WatchlistPage({
          onOpenAlertEditor: (symbolId: string, alertId: string) => this.openAlertEditor(symbolId, alertId),
          onOpenPositionEditor: (symbolId: string) => this.openPositionEditor(symbolId)
        })
      }
      .tabBar(this.tabBarBuilder('⌁', '自选', 0))

      TabContent() {
        AlertsPage({
          onOpenEditor: (symbolId: string, alertId: string) => this.openAlertEditor(symbolId, alertId)
        })
      }
      .tabBar(this.tabBarBuilder('◎', '提醒', 1))

      TabContent() {
        PositionsPage({
          onOpenEditor: (symbolId: string) => this.openPositionEditor(symbolId)
        })
      }
      .tabBar(this.tabBarBuilder('▣', '持仓', 2))

      TabContent() {
        SettingsPage()
      }
      .tabBar(this.tabBarBuilder('⚙', '设置', 3))
    }
    .width('100%')
    .height('100%')
    .vertical(false)
    .scrollable(false)
    .barMode(BarMode.Fixed)
    .barHeight(68 + this.bottomSafeHeight)
    .barBackgroundColor('#121720')
    .onChange((index: number) => {
      AppStorage.set<number>('managementTab', index)
    })
  }

  build() {
    Stack() {
      if (this.managementRoute === ManagementRoute.ALERT_EDITOR) {
        AlertEditorPage({
          initialSymbolId: this.editorSymbolId,
          alertId: this.editorAlertId,
          onBack: () => this.closeEditor()
        })
      } else if (this.managementRoute === ManagementRoute.POSITION_EDITOR) {
        PositionEditorPage({
          initialSymbolId: this.editorSymbolId,
          onBack: () => this.closeEditor()
        })
      } else {
        this.rootTabs()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0C1017')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
