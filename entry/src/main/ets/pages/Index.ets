import { promptAction, router, UIContext } from '@kit.ArkUI';
import { ShowScreenshotItem } from '../components/ShowScreenshotItem';
import { ScreenshotItem } from '../model/types/ScreenshotItem';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DataManager } from '../utils/DataManager';
import { common } from '@kit.AbilityKit';
import { TimeUtils } from '../utils/TimeUtils';
import { Bill } from './Bill';
import { FileManager } from '../utils/FileManager';
import EntryAbility from '../entryability/EntryAbility';

const MAX_SELECT_NUM = 1; // Select the maximum number of media files.
const TAG = 'Index';
interface ScreenshotEntity {
  id: number;
  uri: string;
  thumbnail: string;
  importTime: number;
  status: string;
  fileName: string;
  category: string;
  createdTime: number;
}

@Entry
@Component
struct Index {
  @State uri: string = '';
  @State isLoading: boolean = true;
  @State ScreenshotItems: Array<ScreenshotItem> = []
  private context: common.UIAbilityContext | null = null;
  // private dataManager: DataManager | null = null;
  private controller: TabsController = new TabsController();
  private listScroller: Scroller = new Scroller();
  @State focusIndex: number = 0;
  @State selectTopIndex: number = 0;
  @State selectBottomIndex: number = 0;
  @State index: number = 0


  async aboutToAppear(): Promise<void> {
    this.context = getContext(this) as common.UIAbilityContext;
    // const context = UIContext.getHostContext() as common.UIAbilityContext;
    await this.initializeDataManager()
    await this.loadScreenshotsFromDatabase();
  }

  private async initializeDataManager(): Promise<void> {
    try {
      // this.dataManager = EntryAbility.getDataManager();
      // 通过 AppStorage 获取
      this.dataManager = AppStorage.get<DataManager>('DataManager')

      if (!dataManager) {
        hilog.error(0xFF00, TAG, `DataManager 获取失败(不存在)`);
        throw new Error('DataManager 获取失败');
      }
    } catch (error) {
      const bizError = error as BusinessError;
      hilog.error(0xFF00, TAG, `失败详情：
      Code: ${bizError.code},
      Message: ${bizError.message},
      Stack: ${bizError.stack || '无堆栈信息'}`);
      promptAction.showToast({ message: '数据服务不可用' });
      throw new Error(`DataManager 初始化失败: ${bizError.code}`);
    }

  }

  // 从数据库加载截图列表
  async loadScreenshotsFromDatabase(): Promise<void> {
    if (!this.context) {
      hilog.error(0xFF00, TAG, 'Context 未初始化');
      return;
    }
    try {
      this.isLoading = true;

      // 初始化数据库（如果未初始化）
      const dataManager = await DataManager.create(this.context);

      // 获取所有截图
      const screenshots = await dataManager.getAllScreenshots();

      // 转换为前端需要的格式
      this.ScreenshotItems = screenshots.map(item => ({
        id: item.id,
        uri: item.uri,
        thumbnail: item.thumbnail,
        importTime: Number(item.importTime) || Date.now(),
        status: item.status,
        fileName: item.fileName,
        category: item.category ?? '未分类' ,// 处理可选字段
        createdTime: item.createdTime, // 补充缺失字段
      } as ScreenshotEntity));

      hilog.info(0xFF00, TAG, `从数据库加载了 ${this.ScreenshotItems.length} 个截图`);
    } catch (error) {
      hilog.error(0xFF00, TAG, '加载截图列表失败: ' + JSON.stringify(error));
      promptAction.showToast({ message: '加载失败' });
      // 如果数据库为空，可以显示空状态或保持空数组
    } finally {
      this.isLoading = false;
    }
  }

  // 使用picker选择图片
  async callFilePickerSelectImage(): Promise<void> {
    let array: string[];
    try {
      let PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      PhotoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; // 只选择图片
      PhotoSelectOptions.maxSelectNumber = MAX_SELECT_NUM;
      // Create a PhotoViewPicker object.
      let photoPicker = new photoAccessHelper.PhotoViewPicker(); // 调用相册选择
      photoPicker.select(PhotoSelectOptions).then(async (PhotoSelectResult) => {
        hilog.info(0xFF00, TAG,
          'PhotoViewPicker.select successfully, PhotoSelectResult uri: ' + JSON.stringify(PhotoSelectResult));
        if (PhotoSelectResult?.photoUris?.length > 0) {
          // Declare variable array, whose value is the array in PhotoSelectResult.
          array = PhotoSelectResult['photoUris'];
          array.forEach((value) => {
            this.uri = value;
            hilog.info(0xFF00, TAG, `select image uri: ${this.uri}`);
          })
          await this.processSelectedImage(this.uri);
        }
      }).catch((err: BusinessError) => {
        hilog.error(0xFF00, TAG, 'PhotoViewPicker.select failed with err: ' + JSON.stringify(err));
      })
    } catch (err) {
      hilog.error(0xFF00, TAG, 'PhotoViewPicker failed with err: ' + err);
    }
  }

  // 处理选中的图片
  async processSelectedImage(uri: string): Promise<void> {
    if (!this.context) {
      hilog.error(0xFF00, TAG, 'Context 未初始化');
      return;
    }

    try {
      // 生成文件名和时间
      const fileManager = FileManager.getInstance();
      const originalFileName = await this.getFileNameFromUri(uri);
      const sandboxUri = await fileManager.copyFileToSandbox(uri, originalFileName);
      const thumbnailUri = await fileManager.createThumbnail(uri, originalFileName);
      const importTime = TimeUtils.getCurrentTime();

      // 使用新的异步创建方法
      const dataManager = await DataManager.create(this.context);
      const screenshotId = await dataManager.saveScreenshot({
        uri: sandboxUri,
        thumbnail: thumbnailUri,
        fileName: originalFileName,
        importTime: importTime
      });

      // 重新加载列表
      await this.loadScreenshotsFromDatabase();

      // 跳转到分类选择页面，传递数据库ID
      router.pushUrl({
        url: 'pages/CategorySelect',
        params: {
          screenshotId: screenshotId.toString()
        }
      });

    } catch (error) {
      hilog.error(0xFF00, TAG, '处理图片失败: ' + JSON.stringify(error));
      promptAction.showToast({ message: '处理图片失败' });
    }
  }

  // 从URI获取文件名
  private async getFileNameFromUri(uri: string): Promise<string> {
    try {
      const segments = uri.split('/');
      return segments[segments.length - 1] || `截图_${this.formatDate(new Date())}.png`;
    } catch (error) {
      return `截图_${this.formatDate(new Date())}.png`;
    }
  }

  // 工具方法
  private formatDate(date: Date): string {
    return `${date.getFullYear()}${(date.getMonth() + 1).toString().padStart(2, '0')}${date.getDate().toString().padStart(2, '0')}`;
  }

  @Builder tabTopBuilder(title: string, targetIndex: number) {
    Column() {
      Text(title)
        .fontColor(this.selectTopIndex === targetIndex ? '#1698CE' : '#6B6B6B')
    }
    .height(30)
  }

  @Builder tabBottomBuilder(title: string, targetIndex: number) {
    Column() {
      Text(title)
        .fontColor(this.selectBottomIndex === targetIndex ? '#1698CE' : '#6B6B6B')
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Text('智能记录')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20 })
      Tabs({ barPosition: BarPosition.End }) {
        TabContent(){
          Tabs() {
            TabContent() {
              // 未分析截图列表
              List({ space: 10 }) {
                ForEach(this.ScreenshotItems, (item: ScreenshotItem) => {
                  ListItem() {
                    ShowScreenshotItem({ item: item })
                      .onClick(() => {
                        // 点击跳转到识别页，传递模拟数据
                        console.info('ScreenshotItem Object:', JSON.stringify(item));
                        router.pushUrl({
                          url: 'pages/CategorySelect',
                          params: { screenshotData: JSON.stringify(item) }
                        });
                      })
                  }
                }, (item: ScreenshotItem) => item.id.toString())
              }
              .height('100%')
              .layoutWeight(1)
              .width('100%')
            }.tabBar(this.tabTopBuilder('全部', 0))

            TabContent() {
              Text("未分类")
                .width('100%')
                .height('100%')
                .backgroundColor('rgb(112,112,112)')
                .fontSize(40)
                .fontColor(Color.Black)
                .textAlign(TextAlign.Center)
            }.tabBar(this.tabTopBuilder('未分类', 1))
          }
          .onChange((index: number) => {
            this.selectTopIndex = index;
          })
        }.tabBar(this.tabBottomBuilder('首页',0))

        TabContent() {
          // Bill()
        }.tabBar(this.tabBottomBuilder('账单',1))
      }
      .height("90%")
      .onChange((index: number) => {
        this.selectBottomIndex = index;
      })

      // 底部FAB按钮
      Button('+')
        .width(60)
        .height(60)
        .backgroundColor('#007DFF')
        .fontColor(Color.White)
        .fontSize(24)
        .borderRadius(30)
        .position({ x: '85%', y: '85%' })
        .onClick(() => {
          this.callFilePickerSelectImage();
        })
    }
    .width('100%')
    .height('100%')
    .padding({left:16, right:16})
  }
}
