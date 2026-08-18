import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { display, window } from '@kit.ArkUI'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { CapsuleDimensions, CapsuleSize } from './PersonalModels'
import { personalStore } from './PersonalStore'

export class FloatWindowManager {
  private static singleton: FloatWindowManager = new FloatWindowManager()
  private context?: common.UIAbilityContext
  private floatWindow?: window.Window
  private x: number = 0
  private y: number = 0
  private dragStartX: number = 0
  private dragStartY: number = 0
  private systemMoving: boolean = false
  private dragActive: boolean = false
  private moving: boolean = false
  private pendingMoveX: number = -1
  private pendingMoveY: number = -1
  private lastMoveAt: number = 0
  private density: number = 1
  private screenWidth: number = 1080
  private screenHeight: number = 1920
  private dataPreferences?: preferences.Preferences
  private suspendDelayInfo?: backgroundTaskManager.DelaySuspendInfo
  private suspendDelayUnavailable: boolean = false
  private abilityInForeground: boolean = true
  private displayListenerRegistered: boolean = false
  private displayChangeListener: (displayId: number) => void = (_displayId: number) => {
    this.handleDisplayChange()
  }

  static getInstance(): FloatWindowManager {
    return FloatWindowManager.singleton
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    try {
      this.dataPreferences = await preferences.getPreferences(context, 'stock_float_mvp')
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('floatStatus', `悬浮位置将不保存 · ${businessError.message}`)
    }
    this.refreshDisplayMetrics()
    if (!this.displayListenerRegistered) {
      try {
        display.on('change', this.displayChangeListener)
        this.displayListenerRegistered = true
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        console.info(`Display change listener unavailable. Code: ${businessError.code}, message: ${businessError.message}`)
      }
    }
  }

  async show(userInitiated: boolean = true): Promise<void> {
    if (this.floatWindow !== undefined) {
      try {
        await this.floatWindow.showWindow()
        AppStorage.set<boolean>('floatVisible', true)
        if (userInitiated) {
          await personalStore.setFloatUserEnabled(true)
        }
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        AppStorage.set<string>('floatStatus', `显示悬浮窗失败 ${businessError.code}: ${businessError.message}`)
      }
      return
    }
    if (this.context === undefined) {
      AppStorage.set<string>('floatStatus', '悬浮窗上下文尚未初始化')
      return
    }
    try {
      this.floatWindow = await window.createWindow({
        name: 'stockFloatCapsule',
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: this.context
      })
      const width: number = this.currentWidthPx(false)
      const height: number = this.currentHeightPx(false)
      await this.floatWindow.resize(width, height)
      const storedX: number = Number(this.dataPreferences?.getSync('float_x', this.screenWidth - width - this.vpToPx(12)))
      const storedOnRight: boolean = this.dataPreferences?.getSync(
        'float_on_right', storedX + width / 2 >= this.screenWidth / 2) as boolean
      this.x = storedOnRight ? this.screenWidth - width - this.vpToPx(8) : this.vpToPx(8)
      this.y = Number(this.dataPreferences?.getSync('float_y', this.vpToPx(120)))
      this.clampPosition(width, height)
      await this.floatWindow.moveWindowTo(this.x, this.y)
      await this.floatWindow.setUIContent('pages/FloatCapsule')
      this.floatWindow.setWindowBackgroundColor('#00000000')
      await this.floatWindow.showWindow()
      AppStorage.set<boolean>('floatExpanded', false)
      AppStorage.set<boolean>('floatVisible', true)
      AppStorage.set<string>('floatStatus', '全局悬浮胶囊运行中')
      AppStorage.set<boolean>('backgroundActive', true)
      if (userInitiated) {
        await personalStore.setFloatUserEnabled(true)
      }
      if (!this.abilityInForeground) {
        this.requestSuspendDelay()
      }
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      this.floatWindow = undefined
      AppStorage.set<boolean>('floatVisible', false)
      if (businessError.code === 201) {
        AppStorage.set<string>('floatStatus', '缺少 SYSTEM_FLOAT_WINDOW ACL；当前可使用下方应用内预览')
      } else {
        AppStorage.set<string>('floatStatus', `创建悬浮窗失败 ${businessError.code}: ${businessError.message}`)
      }
    }
  }

  async hide(rememberDisabled: boolean = true): Promise<void> {
    if (this.floatWindow === undefined) {
      if (rememberDisabled) {
        await personalStore.setFloatUserEnabled(false)
      }
      return
    }
    try {
      await this.floatWindow.destroyWindow()
      AppStorage.set<string>('floatStatus', '全局悬浮胶囊已关闭')
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('floatStatus', `关闭悬浮窗失败 ${businessError.code}: ${businessError.message}`)
    } finally {
      this.floatWindow = undefined
      this.dragActive = false
      this.systemMoving = false
      this.moving = false
      this.pendingMoveX = -1
      this.pendingMoveY = -1
      this.lastMoveAt = 0
      this.cancelSuspendDelay()
      AppStorage.set<boolean>('floatVisible', false)
      AppStorage.set<boolean>('floatExpanded', false)
      if (rememberDisabled) {
        await personalStore.setFloatUserEnabled(false)
      }
    }
  }

  async shutdown(): Promise<void> {
    await this.hide(false)
    if (this.displayListenerRegistered) {
      try {
        display.off('change', this.displayChangeListener)
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        console.info(`Failed to remove display listener. Code: ${businessError.code}`)
      }
      this.displayListenerRegistered = false
    }
  }

  // startMoving 只接受"窗口内"的像素偏移（手指相对窗口左上角，且不超过窗口宽高），
  // 传屏幕全局坐标会触发系统先把窗口"校正到光标位置"，造成起拖瞬间跳变抖动。
  startDrag(windowXVp: number = 0, windowYVp: number = 0): void {
    if (this.floatWindow === undefined || this.dragActive) {
      return
    }
    try {
      const rect: window.Rect = this.floatWindow.getWindowProperties().windowRect
      this.dragActive = true
      this.dragStartX = rect.left
      this.dragStartY = rect.top
      this.pendingMoveX = -1
      this.pendingMoveY = -1
      this.lastMoveAt = 0
      this.systemMoving = false
      if (windowXVp > 0 || windowYVp > 0) {
        const offsetX: number = Math.min(this.vpToPx(windowXVp), rect.width)
        const offsetY: number = Math.min(this.vpToPx(windowYVp), rect.height)
        try {
          this.systemMoving = true
          this.floatWindow.startMoving(offsetX, offsetY).catch((error: BusinessError) => {
            this.systemMoving = false
            // 部分设备形态不支持把窗口拖动交给系统（startMoving 返回 capability 受限错误），
            // 这属于设备能力限制而非权限问题，静默降级为手动拖动，不再向用户展示报错状态。
            console.info(`startMoving not supported (device capability limited), fallback to manual drag. Code: ${error.code}, message: ${error.message}`)
          })
        } catch (error) {
          this.systemMoving = false
          const businessError: BusinessError = error as BusinessError
          console.error(`startMoving unavailable, fallback to manual drag. Code: ${businessError.code}, message: ${businessError.message}`)
        }
      }
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      this.dragActive = false
      AppStorage.set<string>('floatStatus', `读取悬浮窗位置失败 · ${businessError.message}`)
    }
  }

  dragBy(offsetXVp: number, offsetYVp: number): void {
    if (this.floatWindow === undefined) {
      return
    }
    if (this.systemMoving) {
      return
    }
    const expanded: boolean = AppStorage.get<boolean>('floatExpanded') ?? false
    const width: number = this.currentWidthPx(expanded)
    const height: number = this.currentHeightPx(expanded)
    this.x = Math.round(this.dragStartX + this.vpToPx(offsetXVp))
    this.y = Math.round(this.dragStartY + this.vpToPx(offsetYVp))
    this.clampPosition(width, height)
    const now: number = Date.now()
    if (now - this.lastMoveAt < 16) {
      this.pendingMoveX = this.x
      this.pendingMoveY = this.y
      return
    }
    this.lastMoveAt = now
    this.moveWithoutWaiting(this.x, this.y)
  }

  async endDrag(): Promise<void> {
    if (this.floatWindow === undefined || !this.dragActive) {
      return
    }
    this.dragActive = false
    const expanded: boolean = AppStorage.get<boolean>('floatExpanded') ?? false
    const width: number = this.currentWidthPx(expanded)
    const height: number = this.currentHeightPx(expanded)
    const margin: number = this.vpToPx(8)
    this.pendingMoveX = -1
    this.pendingMoveY = -1
    this.lastMoveAt = 0
    try {
      const rect: window.Rect = this.floatWindow.getWindowProperties().windowRect
      this.x = rect.left
      this.y = rect.top
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('floatStatus', `读取拖动终点失败 · ${businessError.message}`)
    }
    this.systemMoving = false
    this.x = this.x + width / 2 < this.screenWidth / 2 ? margin : this.screenWidth - width - margin
    this.clampPosition(width, height)
    try {
      await this.floatWindow.moveWindowTo(this.x, this.y)
      await this.savePosition()
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('floatStatus', `吸附悬浮窗失败 · ${businessError.message}`)
    }
  }

  async toggleExpanded(): Promise<void> {
    if (this.floatWindow === undefined) {
      return
    }
    try {
      const nextExpanded: boolean = !(AppStorage.get<boolean>('floatExpanded') ?? false)
      const width: number = this.currentWidthPx(nextExpanded)
      const height: number = this.currentHeightPx(nextExpanded)
      const oldRect: window.Rect = this.floatWindow.getWindowProperties().windowRect
      const wasRight: boolean = oldRect.left + oldRect.width / 2 >= this.screenWidth / 2
      await this.floatWindow.resize(width, height)
      this.x = wasRight ? this.screenWidth - width - this.vpToPx(8) : this.vpToPx(8)
      this.y = oldRect.top
      this.clampPosition(width, height)
      await this.floatWindow.moveWindowTo(this.x, this.y)
      AppStorage.set<boolean>('floatExpanded', nextExpanded)
      await this.savePosition()
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('floatStatus', `切换悬浮窗尺寸失败 · ${businessError.message}`)
    }
  }

  onAbilityBackground(): void {
    this.abilityInForeground = false
    if (this.floatWindow !== undefined) {
      AppStorage.set<boolean>('backgroundActive', true)
      this.requestSuspendDelay()
    }
  }

  onAbilityForeground(): void {
    this.abilityInForeground = true
    this.cancelSuspendDelay()
    this.suspendDelayUnavailable = false
    AppStorage.set<boolean>('backgroundActive', true)
    if (this.floatWindow !== undefined) {
      AppStorage.set<string>('floatStatus', '全局悬浮胶囊运行中')
    }
  }

  async applyPresentationSettings(): Promise<void> {
    if (this.floatWindow === undefined) {
      return
    }
    const expanded: boolean = AppStorage.get<boolean>('floatExpanded') ?? false
    const width: number = this.currentWidthPx(expanded)
    const height: number = this.currentHeightPx(expanded)
    try {
      const oldRect: window.Rect = this.floatWindow.getWindowProperties().windowRect
      const onRight: boolean = oldRect.left + oldRect.width / 2 >= this.screenWidth / 2
      await this.floatWindow.resize(width, height)
      this.x = onRight ? this.screenWidth - width - this.vpToPx(8) : this.vpToPx(8)
      this.y = oldRect.top
      this.clampPosition(width, height)
      await this.floatWindow.moveWindowTo(this.x, this.y)
      await this.savePosition()
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('floatStatus', `应用胶囊设置失败 · ${businessError.message}`)
    }
  }

  private vpToPx(value: number): number {
    return Math.round(value * this.density)
  }

  private currentWidthPx(expanded: boolean): number {
    const size: CapsuleSize = personalStore.capsuleSize()
    const desired: number = this.vpToPx(expanded ? CapsuleDimensions.expandedWidth(size) :
      CapsuleDimensions.collapsedWidth(size))
    return Math.min(desired, Math.max(this.vpToPx(160), this.screenWidth - this.vpToPx(16)))
  }

  private currentHeightPx(expanded: boolean): number {
    const size: CapsuleSize = personalStore.capsuleSize()
    const desired: number = this.vpToPx(expanded ? CapsuleDimensions.expandedHeight(size) :
      CapsuleDimensions.collapsedHeight(size))
    return expanded ? Math.min(desired, Math.max(this.vpToPx(240), this.screenHeight - this.vpToPx(56))) : desired
  }

  private refreshDisplayMetrics(): void {
    try {
      const currentDisplay: display.Display = display.getDefaultDisplaySync()
      this.density = currentDisplay.densityPixels
      this.screenWidth = currentDisplay.width
      this.screenHeight = currentDisplay.height
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('floatStatus', `读取屏幕尺寸失败 · ${businessError.message}`)
    }
  }

  private async handleDisplayChange(): Promise<void> {
    this.refreshDisplayMetrics()
    await this.applyPresentationSettings()
  }

  private clampPosition(width: number, height: number): void {
    this.x = Math.round(Math.min(Math.max(0, this.x), Math.max(0, this.screenWidth - width)))
    this.y = Math.round(Math.min(Math.max(this.vpToPx(28), this.y), Math.max(0, this.screenHeight - height - this.vpToPx(28))))
  }

  private async savePosition(): Promise<void> {
    if (this.dataPreferences === undefined || this.floatWindow === undefined) {
      return
    }
    try {
      const rect: window.Rect = this.floatWindow.getWindowProperties().windowRect
      this.dataPreferences.putSync('float_x', this.x)
      this.dataPreferences.putSync('float_y', this.y)
      this.dataPreferences.putSync('float_on_right', this.x + rect.width / 2 >= this.screenWidth / 2)
      await this.dataPreferences.flush()
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('floatStatus', `保存悬浮位置失败 · ${businessError.message}`)
    }
  }

  private async moveWithoutWaiting(x: number, y: number): Promise<void> {
    if (this.floatWindow === undefined) {
      return
    }
    if (this.moving) {
      this.pendingMoveX = x
      this.pendingMoveY = y
      return
    }
    this.moving = true
    try {
      await this.floatWindow.moveWindowTo(x, y)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.error(`Failed to drag float window. Code: ${businessError.code}, message: ${businessError.message}`)
    } finally {
      this.moving = false
      if (this.pendingMoveX >= 0 && this.pendingMoveY >= 0) {
        const nextX: number = this.pendingMoveX
        const nextY: number = this.pendingMoveY
        this.pendingMoveX = -1
        this.pendingMoveY = -1
        this.moveWithoutWaiting(nextX, nextY)
      }
    }
  }

  private requestSuspendDelay(): void {
    if (this.context === undefined || this.suspendDelayInfo !== undefined || this.suspendDelayUnavailable) {
      return
    }
    try {
      this.suspendDelayInfo = backgroundTaskManager.requestSuspendDelay(
        'stock float rotation',
        () => {
          this.suspendDelayInfo = undefined
          if (this.floatWindow !== undefined && !this.abilityInForeground) {
            AppStorage.set<boolean>('backgroundActive', false)
            AppStorage.set<string>('floatStatus', '悬浮胶囊运行中 · 后台轮播延迟已到期')
          }
        }
      )
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      this.suspendDelayInfo = undefined
      this.suspendDelayUnavailable = true
      AppStorage.set<boolean>('backgroundActive', false)
      if (businessError.code === 9900001 || businessError.code === 9900002) {
        AppStorage.set<string>('floatStatus', '悬浮胶囊运行中 · 系统限制后台轮播')
        console.info(`Transient background task unavailable on this device. Code: ${businessError.code}, message: ${businessError.message}`)
      } else {
        AppStorage.set<string>('floatStatus', '悬浮胶囊运行中 · 后台轮播暂不可用')
        console.error(`Failed to request transient background task. Code: ${businessError.code}, message: ${businessError.message}`)
      }
    }
  }

  private cancelSuspendDelay(): void {
    if (this.suspendDelayInfo === undefined) {
      return
    }
    try {
      backgroundTaskManager.cancelSuspendDelay(this.suspendDelayInfo.requestId)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.error(`Failed to cancel suspend delay. Code: ${businessError.code}, message: ${businessError.message}`)
    } finally {
      this.suspendDelayInfo = undefined
    }
  }
}

export const floatWindowManager: FloatWindowManager = FloatWindowManager.getInstance()
