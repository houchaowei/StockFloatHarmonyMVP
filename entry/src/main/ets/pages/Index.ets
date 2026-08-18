import { AlertEditorPage } from './AlertEditorPage'
import { AlertsPage } from './AlertsPage'
import { PositionEditorPage } from './PositionEditorPage'
import { PositionsPage } from './PositionsPage'
import { SettingsPage } from './SettingsPage'
import { WatchlistPage } from './WatchlistPage'
import { ApplicationTheme } from '../model/ApplicationTheme'

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
  @StorageLink('capsuleBackground') capsuleBackground: string = 'black'
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

  private selectTab(index: number): void {
    AppStorage.set<number>('managementTab', index)
  }

  @Builder
  navigationItem(icon: Resource, label: string, index: number) {
    Column({ space: 2 }) {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(this.managementTab === index ? ApplicationTheme.color(this.capsuleBackground, '#6F9BFF') : ApplicationTheme.color(this.capsuleBackground, '#758196'))
        .objectFit(ImageFit.Contain)
      Text(label)
        .fontSize(11)
        .lineHeight(16)
        .height(16)
        .fontWeight(this.managementTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.managementTab === index ? ApplicationTheme.color(this.capsuleBackground, '#9DB8FF') : ApplicationTheme.color(this.capsuleBackground, '#758196'))
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .height(60)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(`${label}${this.managementTab === index ? '，已选中' : ''}`)
    .onClick(() => this.selectTab(index))
  }

  @Builder
  rootShell() {
    Column() {
      Stack() {
        WatchlistPage({
          onOpenAlertEditor: (symbolId: string, alertId: string) => this.openAlertEditor(symbolId, alertId),
          onOpenPositionEditor: (symbolId: string) => this.openPositionEditor(symbolId)
        })
          .visibility(this.managementTab === 0 ? Visibility.Visible : Visibility.None)

        AlertsPage({
          onOpenEditor: (symbolId: string, alertId: string) => this.openAlertEditor(symbolId, alertId)
        })
          .visibility(this.managementTab === 1 ? Visibility.Visible : Visibility.None)

        PositionsPage({
          onOpenEditor: (symbolId: string) => this.openPositionEditor(symbolId)
        })
          .visibility(this.managementTab === 2 ? Visibility.Visible : Visibility.None)

        SettingsPage()
          .visibility(this.managementTab === 3 ? Visibility.Visible : Visibility.None)
      }
      .layoutWeight(1)
      .width('100%')

      Row() {
        this.navigationItem($r('app.media.nav_watchlist'), '自选', 0)
        this.navigationItem($r('app.media.nav_alerts'), '提醒', 1)
        this.navigationItem($r('app.media.nav_positions'), '持仓', 2)
        this.navigationItem($r('app.media.nav_settings'), '设置', 3)
      }
      .width('100%')
      .height(60 + this.bottomSafeHeight)
      .padding({ bottom: this.bottomSafeHeight })
      .alignItems(VerticalAlign.Top)
      .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#121720'))
    }
    .width('100%')
    .height('100%')
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
        this.rootShell()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#0C1017'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
