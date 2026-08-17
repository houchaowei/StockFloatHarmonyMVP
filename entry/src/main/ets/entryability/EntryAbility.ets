import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { display, window } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { floatWindowManager } from '../model/FloatWindowManager'
import { quoteStore } from '../model/QuoteStore'
import { personalStore } from '../model/PersonalStore'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<string>('managementRoute', 'root')
    AppStorage.set<string>('managementRoute', 'root')
    AppStorage.setOrCreate<number>('managementTab', 0)
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    try {
      await personalStore.initialize(this.context)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('alertStatus', `初始化个性化设置失败 · ${businessError.message}`)
    }
    try {
      await quoteStore.initialize(this.context)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('quoteStatus', `读取本地自选失败 · ${businessError.message}`)
    }
    try {
      await floatWindowManager.initialize(this.context)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('floatStatus', `初始化悬浮窗失败 · ${businessError.message}`)
    }
    try {
      await windowStage.loadContent('pages/Index')
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.error(`Failed to load Index. Code: ${businessError.code}, message: ${businessError.message}`)
      return
    }
    await this.applyEdgeToEdgeLayout(windowStage)
    quoteStore.start()
    if (personalStore.shouldRestoreFloat()) {
      await floatWindowManager.show(false)
    }
  }

  private async applyEdgeToEdgeLayout(windowStage: window.WindowStage): Promise<void> {
    try {
      const mainWindow: window.Window = await windowStage.getMainWindow()
      await mainWindow.setWindowLayoutFullScreen(true)
      await mainWindow.setWindowBackgroundColor('#0C1017')
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#0C1017',
        statusBarContentColor: '#F7F9FC',
        navigationBarColor: '#0C1017',
        navigationBarContentColor: '#F7F9FC'
      })
      this.publishSafeInsets(mainWindow)
      mainWindow.on('avoidAreaChange', () => this.publishSafeInsets(mainWindow))
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.error(`Failed to apply edge-to-edge layout. Code: ${businessError.code}, message: ${businessError.message}`)
    }
  }

  private publishSafeInsets(mainWindow: window.Window): void {
    try {
      const density: number = display.getDefaultDisplaySync().densityPixels
      const systemArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      AppStorage.setOrCreate<number>('topSafeHeight', systemArea.topRect.height / density)
      const indicatorArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      AppStorage.setOrCreate<number>('bottomSafeHeight', indicatorArea.bottomRect.height / density)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.error(`Failed to read safe insets. Code: ${businessError.code}, message: ${businessError.message}`)
    }
  }

  onWindowStageDestroy(): void {
  }

  onDestroy(): void {
    quoteStore.stop()
    floatWindowManager.shutdown()
  }

  onForeground(): void {
    floatWindowManager.onAbilityForeground()
    quoteStore.refresh()
  }

  onBackground(): void {
    floatWindowManager.onAbilityBackground()
  }

  onBackPressed(): boolean {
    const route: string = AppStorage.get<string>('managementRoute') ?? 'root'
    if (route !== 'root') {
      AppStorage.set<string>('managementRoute', 'root')
      return true
    }
    return false
  }
}
