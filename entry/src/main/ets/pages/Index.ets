import { promptAction, router, UIContext } from '@kit.ArkUI';
import { ShowScreenshotItem } from '../components/ShowScreenshotItem';
import { ScreenshotItem } from '../model/types/ScreenshotItem';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DataManager } from '../utils/DataManager';
import { common } from '@kit.AbilityKit';
import { Bill } from './Bill';
import { FileManager } from '../utils/FileManager';
import EntryAbility from '../entryability/EntryAbility';
import { UploadView } from '../view/UploadView';
import { RecordItem } from '../view/RecordItem';
import { RecordListView } from '../view/RecordListView';
import { SearchView } from '../view/SearchView';

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
  private controller: TabsController = new TabsController();
  private listScroller: Scroller = new Scroller();
  @State currentIndex: number = 0
  @State focusIndex: number = 0;
  @State selectTopIndex: number = 0;
  @State selectBottomIndex: number = 0;
  @State index: number = 0
  @State refreshTrigger: number = 0                             // 刷新信号灯


  async aboutToAppear(): Promise<void> {
    this.context = getContext(this) as common.UIAbilityContext;
  }

  // 页面每次展示到屏幕上时触发（包括从详情页 back 回来）
  onPageShow() {
    this.refreshTrigger++
  }


  // 自定义 Tab 标签样式
  @Builder TabBuilder(title: string, index: number, selectedImg: Resource, normalImg: Resource) {
    Column() {
      Image(this.currentIndex === index ? selectedImg : normalImg)
        .width(24)
        .height(24)
        .margin({ bottom: 4 })
      Text(title)
        .fontColor(this.currentIndex === index ? '#007DFF' : '#182431')
        .fontSize(10)
        .fontWeight(500)
    }.width('100%')
  }

  // // 使用picker选择图片
  // async callFilePickerSelectImage(): Promise<void> {
  //   let array: string[];
  //   try {
  //     let PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
  //     PhotoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; // 只选择图片
  //     PhotoSelectOptions.maxSelectNumber = MAX_SELECT_NUM;
  //     // Create a PhotoViewPicker object.
  //     let photoPicker = new photoAccessHelper.PhotoViewPicker(); // 调用相册选择
  //     photoPicker.select(PhotoSelectOptions).then(async (PhotoSelectResult) => {
  //       hilog.info(0xFF00, TAG,
  //         'PhotoViewPicker.select successfully, PhotoSelectResult uri: ' + JSON.stringify(PhotoSelectResult));
  //       if (PhotoSelectResult?.photoUris?.length > 0) {
  //         // Declare variable array, whose value is the array in PhotoSelectResult.
  //         array = PhotoSelectResult['photoUris'];
  //         array.forEach((value) => {
  //           this.uri = value;
  //           hilog.info(0xFF00, TAG, `select image uri: ${this.uri}`);
  //         })
  //         await this.processSelectedImage(this.uri);
  //       }
  //     }).catch((err: BusinessError) => {
  //       hilog.error(0xFF00, TAG, 'PhotoViewPicker.select failed with err: ' + JSON.stringify(err));
  //     })
  //   } catch (err) {
  //     hilog.error(0xFF00, TAG, 'PhotoViewPicker failed with err: ' + err);
  //   }
  // }

  // // 处理选中的图片
  // async processSelectedImage(uri: string): Promise<void> {
  //   if (!this.context) {
  //     hilog.error(0xFF00, TAG, 'Context 未初始化');
  //     return;
  //   }
  //
  //   try {
  //     // 生成文件名和时间
  //     const fileManager = FileManager.getInstance();
  //     const originalFileName = await this.getFileNameFromUri(uri);
  //     const sandboxUri = await fileManager.copyFileToSandbox(uri, originalFileName);
  //     const thumbnailUri = await fileManager.createThumbnail(uri, originalFileName);
  //     const importTime = TimeUtils.getCurrentTime();
  //
  //     // 使用新的异步创建方法
  //     const dataManager = await DataManager.create(this.context);
  //     const screenshotId = await dataManager.saveScreenshot({
  //       uri: sandboxUri,
  //       thumbnail: thumbnailUri,
  //       fileName: originalFileName,
  //       importTime: importTime
  //     });
  //
  //     // 重新加载列表
  //     await this.loadScreenshotsFromDatabase();
  //
  //     // 跳转到分类选择页面，传递数据库ID
  //     router.pushUrl({
  //       url: 'pages/CategorySelect',
  //       params: {
  //         screenshotId: screenshotId.toString()
  //       }
  //     });
  //
  //   } catch (error) {
  //     hilog.error(0xFF00, TAG, '处理图片失败: ' + JSON.stringify(error));
  //     promptAction.showToast({ message: '处理图片失败' });
  //   }
  // }

  // // 从URI获取文件名
  // private async getFileNameFromUri(uri: string): Promise<string> {
  //   try {
  //     const segments = uri.split('/');
  //     return segments[segments.length - 1] || `截图_${this.formatDate(new Date())}.png`;
  //   } catch (error) {
  //     return `截图_${this.formatDate(new Date())}.png`;
  //   }
  // }

  // @Builder tabTopBuilder(title: string, targetIndex: number) {
  //   Column() {
  //     Text(title)
  //       .fontColor(this.selectTopIndex === targetIndex ? '#1698CE' : '#6B6B6B')
  //   }
  //   .height(30)
  // }

  // @Builder tabBottomBuilder(title: string, targetIndex: number) {
  //   Column() {
  //     Text(title)
  //       .fontColor(this.selectBottomIndex === targetIndex ? '#1698CE' : '#6B6B6B')
  //   }
  // }

  build() {
    Column() {
      // 顶部标题栏
      Text('智能记录')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20 })
      Tabs({ barPosition: BarPosition.End }) {
        TabContent() {
          UploadView()
        }
        .tabBar(('识别'))

        TabContent() {
          RecordListView({ refreshTrigger: this.refreshTrigger })
        }
        .tabBar('记录')

        TabContent() {
          SearchView({ refreshTrigger: this.refreshTrigger })
        }
        .tabBar('搜索')
      }
      .height("90%")
      .vertical(false)
      .barHeight(56)
      .onChange((index: number) => {
        this.currentIndex = index
        this.selectBottomIndex = index;
        this.refreshTrigger++;
      })

    }
    .width('100%')
    .height('100%')
    .padding({left:16, right:16})
  }
}
