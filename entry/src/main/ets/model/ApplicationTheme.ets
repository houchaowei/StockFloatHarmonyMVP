import { CapsuleBackground } from './PersonalModels'
import { window } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'

export class ApplicationTheme {
  private static mainWindow?: window.Window

  static bindMainWindow(mainWindow: window.Window): void {
    ApplicationTheme.mainWindow = mainWindow
  }

  static async applyWindow(backgroundStyle: string): Promise<void> {
    if (ApplicationTheme.mainWindow === undefined) {
      return
    }
    const appBackground: string = ApplicationTheme.isLight(backgroundStyle) ? '#F4F6F9' : '#0C1017'
    const contentColor: string = ApplicationTheme.isLight(backgroundStyle) ? '#111722' : '#F7F9FC'
    try {
      await ApplicationTheme.mainWindow.setWindowBackgroundColor(appBackground)
      await ApplicationTheme.mainWindow.setWindowSystemBarProperties({
        statusBarColor: appBackground,
        statusBarContentColor: contentColor,
        navigationBarColor: appBackground,
        navigationBarContentColor: contentColor
      })
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.info(`Failed to apply window theme. Code: ${businessError.code}, message: ${businessError.message}`)
    }
  }

  static isLight(backgroundStyle: string): boolean {
    return backgroundStyle === CapsuleBackground.WHITE
  }

  static color(backgroundStyle: string, darkColor: string): ResourceColor {
    if (!ApplicationTheme.isLight(backgroundStyle)) {
      return darkColor
    }
    switch (darkColor.toUpperCase()) {
      case '#0C1017':
        return '#F4F6F9'
      case '#121720':
        return '#FFFFFF'
      case '#171D27':
        return '#EDF1F5'
      case '#222B39':
        return '#E3EBFA'
      case '#252E3B':
        return '#536072'
      case '#3A414D':
        return '#536072'
      case '#243554':
        return '#365C99'
      case '#203B34':
        return '#267057'
      case '#322128':
        return '#F7E4E6'
      case '#F7F9FC':
      case '#F2F5FA':
      case '#EEF2F8':
      case '#E7EBF2':
      case '#DCE2EC':
      case '#FFFFFF':
        return '#111722'
      case '#AAB5C6':
      case '#AAB2C1':
        return '#4E5A6A'
      case '#8FA1BD':
        return '#52637A'
      case '#8893A6':
      case '#8290A6':
      case '#758196':
      case '#68758A':
        return '#647080'
      case '#AEB8C8':
        return '#667384'
      case '#4D5B70':
        return '#AAB4C3'
      case '#71809A':
        return '#65758C'
      case '#3F4858':
        return '#B2BBC6'
      case '#9DB8FF':
      case '#6F9BFF':
        return '#245CCC'
      case '#346DFF':
        return '#245ECC'
      case '#FFB366':
        return '#A85D00'
      case '#F3B85B':
        return '#946100'
      case '#FF8990':
      case '#FF5A63':
        return '#B92731'
      case '#21C78B':
      case '#4AD7A5':
        return '#087A55'
      case '#778398':
        return '#687384'
      default:
        return darkColor
    }
  }
}
