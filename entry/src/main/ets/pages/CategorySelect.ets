import { ScreenshotItem } from '../model/types/ScreenshotItem';
import { promptAction, router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DataManager } from '../utils/DataManager';
import { common } from '@kit.AbilityKit';

const TAG = 'CategorySelect';

@Entry
@Component
struct CategorySelect {
  @State uri:string = ''
  @State screenshotData: ScreenshotItem = {
    id: 0,
    thumbnail: '',
    importTime: 0,
    status: '',
    fileName: '',
    uri: '',
    category: '',
    createdTime: 0
  };
  @State screenshotId: number = 0;
  @State selectedCategory: string = '';
  @State isLoading: boolean = true;
  private context: common.UIAbilityContext | null = null;

  aboutToAppear() {
    // const params = router.getParams() as Record<string, string>;
    // hilog.info(0xFF00, 'CategorySelect', 'Received params: %{public}s', JSON.stringify(params)); // 打印完整参数对象
    // this.uri = params['PhotoSelectResult'];
    // if (params?.['screenshotData']) {
    //   hilog.info(0xFF00, 'CategorySelect', 'Received uri: %{public}s', this.uri); // 打印完整参数对象
    // }
    // 获取当前页面的上下文
    this.context = getContext(this) as common.UIAbilityContext;
    // 开始加载截图数据
    this.loadScreenshotData();
  }

  // 加载截图数据
  async loadScreenshotData(): Promise<void> {
    try {
      this.isLoading = true;
      const params = router.getParams() as Record<string, string>;
      hilog.info(0xFF00, TAG, '接收到的参数: ' + JSON.stringify(params));

      // 优先使用数据库ID
      if (params?.['screenshotId']) {
        this.screenshotId = parseInt(params['screenshotId']);
        hilog.info(0xFF00, TAG, `使用数据库ID加载数据: ${this.screenshotId}`);
        await this.loadScreenshotFromDatabase();
      }
      // 向后兼容：使用直接传递的数据
      else if (params?.['screenshotData']) {
        this.screenshotData = JSON.parse(params['screenshotData']);
        this.screenshotId = this.screenshotData.id;
      } else {
        hilog.error(0xFF00, TAG, '未接收到截图数据');
        promptAction.showToast({ message: '数据加载失败' });
        router.back();
        return;
      }
    } catch (error) {
      hilog.error(0xFF00, TAG, '加载截图数据失败: ' + JSON.stringify(error));
      promptAction.showToast({ message: '数据加载失败' });
      router.back();
    } finally {
      this.isLoading = false;
    }
  }

  // 从数据库加载截图数据
  async loadScreenshotFromDatabase(): Promise<void> {
    if (!this.context) {
      hilog.error(0xFF00, TAG, 'Context 未初始化');
      return;
    }

    try {
      const dataManager = await DataManager.create(this.context);
      const screenshots = await dataManager.getAllScreenshots();
      hilog.info(0xFF00, TAG, `数据库中共有 ${screenshots.length} 个截图`);
      const screenshot = screenshots.find(item => item.id === this.screenshotId);

      if (screenshot) {
        this.screenshotData = {
          id: screenshot.id,
          thumbnail: screenshot.thumbnail,
          importTime: screenshot.importTime,
          status: screenshot.status,
          fileName: screenshot.fileName,
          uri: screenshot.uri,
          category: screenshot.category || '',
          createdTime: screenshot.createdTime || 0
        };
        hilog.info(0xFF00, TAG, `从数据库加载截图成功: ID=${this.screenshotId}`);
      } else {
        hilog.error(0xFF00, TAG, `未找到截图: ID=${this.screenshotId}`);
        promptAction.showToast({ message: '截图数据不存在' });
        router.back();
      }
    } catch (error) {
      hilog.error(0xFF00, TAG, '从数据库加载截图失败: ' + JSON.stringify(error));
      throw new Error;
    }
  }

  // 选择分类
  onCategorySelect(category: string) {
    this.selectedCategory = category;
    hilog.info(0xFF00, TAG, `用户选择了分类: ${category}`);
  }

  // 确认选择并跳转到分析页面
  navigateToAnalyzePage() {
    if (!this.selectedCategory) {
      promptAction.showToast({ message: '请先选择分类' });
      return;
    }

    let targetPage = '';
    let pageTitle = '';

    switch (this.selectedCategory) {
      case 'schedule':
        targetPage = 'pages/ScheduleAnalyze';
        pageTitle = '日程分析';
        break;
      case 'knowledge':
        targetPage = 'pages/KnowledgeAnalyze';
        pageTitle = '知识整理';
        break;
      case 'bill':
        targetPage = 'pages/BillAnalyze';
        pageTitle = '账单记录';
        break;
      default:
        promptAction.showToast({ message: '未知分类' });
        return;
    }

    hilog.info(0xFF00, TAG, `跳转到分析页面: ${targetPage}, 截图ID: ${this.screenshotId}`);

    router.pushUrl({
      url: targetPage,
      params: {
        screenshotId: this.screenshotId.toString(),
        category: this.selectedCategory,
        pageTitle: pageTitle
      }
    });
  }


  build() {
    Column() {
      // 顶部导航
      Row() {
        Text(){
          SymbolSpan($r('sys.symbol.chevron_left'))
        }
          .width(24)
          .height(24)
          .onClick(() => {
            router.back();
          })

        Text('选择分类')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ bottom: 30 })

      // 截图预览
      Text('待分析的截图：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)

      Image(this.screenshotData.uri || $r('app.media.sample1'))
        .width('100%')
        .height("60%")
        .objectFit(ImageFit.Cover)
        .borderRadius(8)
        .margin({ top: 10, bottom: 30 })

      // 分类选择
      Text('请选择分类：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 20 })

      Row({ space: 15 }) {
        this.CategoryButton('日程', 'schedule')
        this.CategoryButton('知识', 'knowledge')
        this.CategoryButton('账单', 'bill')
        this.CategoryButton('待分类', 'null')
      }
      .width('100%')

      // 确认按钮
      Button('确认选择')
        .width('100%')
        .height(50)
        .backgroundColor(this.selectedCategory ? '#007DFF' : '#CCCCCC')
        .fontColor(Color.White)
        .fontSize(18)
        .margin({ top: 40 })
        .enabled(!!this.selectedCategory)
        .onClick(() => {
          if (this.selectedCategory) {
            this.navigateToAnalyzePage();
          }
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }

  @Builder
  CategoryButton(label: string, value: string) {
    Button(label)
      .padding({ left: 20, right: 20, top: 10, bottom: 10 })
      .backgroundColor(this.selectedCategory === value ? '#007DFF' : '#F5F5F5')
      .fontColor(this.selectedCategory === value ? Color.White : '#666666')
      .borderRadius(20)
      .onClick(() => {
        this.selectedCategory = value;
      })
  }
}
