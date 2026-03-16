import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { RdbManager } from '../dao/RdbManager';

import { TokenizerService } from '../service/TokenizerService';
import { MindSporeService } from '../service/MindSporeService';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility'

export default class EntryAbility extends UIAbility {
  // private static dataManager: DataManager | null = null;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    hilog.info(DOMAIN, 'EntryAbility', '应用初始化开始');
    // 应用启动时，初始化本地 SQLite 数据库
    let applicationContext = this.context.getApplicationContext();
    await RdbManager.getInstance().initRdb(this.context)
    applicationContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    // 获取ResourceManager（资源管理）
    let resourceManager = applicationContext.resourceManager;
    // 获取applicationInfo（当前应用信息）
    let applicationInfo = applicationContext.applicationInfo;

    this.initLocalAIEngines();

  }

  /**
   * 专门剥离出来的异步初始化方法
   */
  private async initLocalAIEngines() {
    try {
      // 获取当前 Ability 的全局资源管理器，只有它有权限读取 rawfile
      const resMgr = this.context.resourceManager;

      hilog.info(0x0000, 'EntryAbility', '=== 开始后台初始化端侧 AI 双核引擎 ===');

      // 1. 初始化轻量级分词器 (加载 vocab.txt 字典)
      await TokenizerService.init(resMgr);

      // 2. 初始化 MindSpore Lite NPU 推理引擎 (加载 .ms 模型)
      await MindSporeService.init(resMgr);

      hilog.info(0x0000, 'EntryAbility', '=== 端侧 AI 引擎全部就绪！火力全开 ===');
    } catch (error) {
      hilog.error(0x0000, 'EntryAbility', `引擎初始化遭遇致命错误: ${JSON.stringify(error)}`);
    }
  }


  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    let context = this.context;
    let pathDir = context.filesDir;
    let cacheDir = context.cacheDir;

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}