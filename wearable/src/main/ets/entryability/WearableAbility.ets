import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class WearableAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } catch (err) {
      hilog.error(DOMAIN, 'AuraS-Watch', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'AuraS-Watch', '%{public}s', 'WearableAbility onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'AuraS-Watch', '%{public}s', 'WearableAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'AuraS-Watch', '%{public}s', 'WearableAbility onWindowStageCreate');

    const mainWindow = windowStage.getMainWindowSync();
    mainWindow.setWindowLayoutFullScreen(true);
    const sysBarProps: window.SystemBarProperties = {
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: '#FFFFFF',
      navigationBarContentColor: '#FFFFFF'
    };
    mainWindow.setWindowSystemBarProperties(sysBarProps);

    windowStage.loadContent('pages/WatchHomePage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'AuraS-Watch', 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'AuraS-Watch', 'Succeeded in loading WatchHomePage.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'AuraS-Watch', '%{public}s', 'WearableAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'AuraS-Watch', '%{public}s', 'WearableAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'AuraS-Watch', '%{public}s', 'WearableAbility onBackground');
  }
}
