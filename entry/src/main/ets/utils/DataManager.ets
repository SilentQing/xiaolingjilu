import relationalStore from '@ohos.data.relationalStore';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { FileManager } from './FileManager';

const TAG = 'DataManager';

interface table_COLUMNS {
  ID: string;
  URI: string;
  THUMBNAIL: string;
  IMPORT_TIME: string;
  STATUS: string;
  FILE_NAME: string;
  CREATED_TIME: string;
  CATEGORY: string;
  ANALYZED_TEXT: string;
}
interface ScreenshotInfo {
  uri: string;
  thumbnail?: string;
  importTime: string;
  fileName: string;
}
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

// 状态枚举
enum ScreenshotStatus {
  NotAnalyzed = '未分析',
  Analyzing = '分析中',
  Completed = '已完成',
  Failed = '分析失败'
}
export class DataManager {
  private static instance: DataManager | null = null;
  private static initLock: Promise<void> | null = null;
  private rdbStore: relationalStore.RdbStore | null = null;

  private constructor() {}

  // 数据库配置
  private readonly STORE_CONFIG: relationalStore.StoreConfig = {
    name: 'ScreenshotDB.db',
    securityLevel: relationalStore.SecurityLevel.S1,
    encrypt: false                     // 是否加密
  };

  // 表名和列定义
  private readonly TABLE_NAME = 'screenshots';
  private readonly COLUMNS: table_COLUMNS = {
    ID: 'id',
    URI: 'uri',
    THUMBNAIL: 'thumbnail',
    IMPORT_TIME: 'import_time',
    STATUS: 'status',
    FILE_NAME: 'file_name',
    CREATED_TIME: 'created_time',
    CATEGORY: 'category',
    ANALYZED_TEXT: 'analyzed_text'
  };


  public static async create(context: common.Context): Promise<DataManager> {
    // 快速路径：已初始化
    if (DataManager.instance) {
      return DataManager.instance;
    }

    // 初始化路径：防止并发
    if (!DataManager.initLock) {
      DataManager.initLock = (async (): Promise<void> => {
        try {
          const instance = new DataManager();
          await instance.initDatabase(context);
          DataManager.instance = instance;
        } catch (error) {
          // ✅ 重要：初始化失败时清除锁，允许重试
          DataManager.initLock = null;
          throw new Error;
        }
      })();
    }

    await DataManager.initLock;
    return DataManager.instance!;
  }

  // 获取已存在的实例（如果已初始化）
  public static getInstance(): DataManager {
    if (!DataManager.instance) {
      throw new Error('DataManager 尚未初始化，请先调用 create() 方法');
    }
    return DataManager.instance;
  }

  // 初始化数据库
  async initDatabase(context: common.Context): Promise<void> {
    try {
      this.rdbStore = await relationalStore.getRdbStore(context, this.STORE_CONFIG);
      await this.createTables()
      hilog.info(0xFF00, TAG, '数据库初始化成功');
    } catch (error) {
      hilog.error(0xFF00, TAG, '数据库初始化失败: ' + JSON.stringify(error));
      throw new Error('DATABASE_INIT_FAILED');
    }
  }

  private async createTables(): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('Database store not initialized');
    }
    // 创建表
    const SQL_CREATE_TABLE = `
        CREATE TABLE IF NOT EXISTS ${this.TABLE_NAME} (
          ${this.COLUMNS.ID} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${this.COLUMNS.URI} TEXT NOT NULL,
          ${this.COLUMNS.THUMBNAIL} TEXT,
          ${this.COLUMNS.IMPORT_TIME} INTEGER,
          ${this.COLUMNS.STATUS} TEXT DEFAULT '未分析',
          ${this.COLUMNS.FILE_NAME} TEXT,
          ${this.COLUMNS.CREATED_TIME} INTEGER,
          ${this.COLUMNS.CATEGORY} TEXT,
          ${this.COLUMNS.ANALYZED_TEXT} TEXT
        )`;

    await this.rdbStore.executeSql(SQL_CREATE_TABLE);
    hilog.info(0xFF00, TAG, '数据表创建成功');
  }

  // 保存截图到数据库
  async saveScreenshot(screenshot: ScreenshotInfo): Promise<number> {
    if (!this.rdbStore) {
      throw new Error('数据库未初始化');
    }

    try {
      const valueBucket: relationalStore.ValuesBucket  = {
        uri: screenshot.uri,
        thumbnail: screenshot.thumbnail ?? screenshot.uri,
        import_time: screenshot.importTime,
        file_name: screenshot.fileName,
        created_time: new Date().getTime(),
        status: '未分析'
      };

      const insertId = await this.rdbStore.insert(this.TABLE_NAME, valueBucket);
      hilog.info(0xFF00, TAG, `截图保存成功，ID: ${insertId}`);
      return insertId;
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      hilog.error(0xFF00, TAG, `保存失败 Code:${err.code}, Message:${err.message}`);
      throw new Error('SAVE_SCREENSHOT_FAILED');
    }
  }

  // 获取所有截图（按创建时间倒序）
  async getAllScreenshots(): Promise<Array<ScreenshotEntity>> {
    if (!this.rdbStore) {
      throw new Error('数据库未初始化');
    }

    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.orderByDesc(this.COLUMNS.CREATED_TIME);

      const resultSet = await this.rdbStore.query(
        predicates,
        [
          this.COLUMNS.ID,
          this.COLUMNS.URI,
          this.COLUMNS.THUMBNAIL,
          this.COLUMNS.IMPORT_TIME,
          this.COLUMNS.STATUS,
          this.COLUMNS.FILE_NAME,
          this.COLUMNS.CATEGORY,
          this.COLUMNS.CREATED_TIME
        ]
      );

      const screenshots: Array<ScreenshotEntity> = [];
      while (resultSet.goToNextRow()) {
        const row:ScreenshotEntity = {
          id: resultSet.getDouble(resultSet.getColumnIndex(this.COLUMNS.ID)),
          uri: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.URI)),
          thumbnail: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.THUMBNAIL)),
          importTime: resultSet.getLong(resultSet.getColumnIndex(this.COLUMNS.IMPORT_TIME)),
          status: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.STATUS)),
          fileName: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.FILE_NAME)),
          category: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.CATEGORY)),
          createdTime: resultSet.getLong(resultSet.getColumnIndex(this.COLUMNS.CREATED_TIME))
        };
        screenshots.push(row);
      }

      resultSet.close();
      return screenshots;
    } catch (error) {
      hilog.error(0xFF00, TAG, '获取截图列表失败: ' + JSON.stringify(error));
      throw new Error(`获取截图列表失败: ${error.message}`);
    } finally {

    }
  }

  // 获取未分析的截图
  async getUnanalyzedScreenshots(): Promise<Array<ScreenshotEntity>> {
    if (!this.rdbStore) {
      throw new Error('数据库未初始化');
    }

    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo(this.COLUMNS.STATUS, '未分析');
      predicates.orderByDesc(this.COLUMNS.CREATED_TIME);

      const resultSet = await this.rdbStore.query(
        predicates,
        [
          this.COLUMNS.ID,
          this.COLUMNS.URI,
          this.COLUMNS.THUMBNAIL,
          this.COLUMNS.IMPORT_TIME,
          this.COLUMNS.STATUS,
          this.COLUMNS.FILE_NAME,
          this.COLUMNS.CATEGORY,
          this.COLUMNS.CREATED_TIME
        ]
      );

      const screenshots: Array<ScreenshotEntity> = [];
      while (resultSet.goToNextRow()) {
        const row:ScreenshotEntity = {
          id: resultSet.getDouble(resultSet.getColumnIndex(this.COLUMNS.ID)),
          uri: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.URI)),
          thumbnail: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.THUMBNAIL)),
          importTime: resultSet.getLong(resultSet.getColumnIndex(this.COLUMNS.IMPORT_TIME)),
          status: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.STATUS)),
          fileName: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.FILE_NAME)),
          category: resultSet.getString(resultSet.getColumnIndex(this.COLUMNS.CATEGORY)),
          createdTime: resultSet.getLong(resultSet.getColumnIndex(this.COLUMNS.CREATED_TIME))
        };
        screenshots.push(row);

      }

      resultSet.close();
      return screenshots;
    } catch (error) {
      hilog.error(0xFF00, TAG, '获取未分析截图失败: ' + JSON.stringify(error));
      throw new Error('获取未分析截图失败');
    }
  }

  // 更新截图状态
  async updateScreenshotStatus(id: number, status: string, category: string): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('数据库未初始化');
    }

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        STATUS: status,
        CATEGORY: category
      };

      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo(this.COLUMNS.ID, id);

      const changedRows = await this.rdbStore.update(valueBucket, predicates);
      hilog.info(0xFF00, TAG, `更新截图状态成功，影响行数: ${changedRows}`);
    } catch (error) {
      hilog.error(0xFF00, TAG, '更新截图状态失败: ' + JSON.stringify(error));
      throw new Error(`更新截图状态失败: ${error.message}`);
    }
  }

  // 删除截图
  async deleteScreenshot(id: number): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('数据库未初始化');
    }

    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo(this.COLUMNS.ID, id);

      const deletedRows = await this.rdbStore.delete(predicates);
      hilog.info(0xFF00, TAG, `删除截图成功，影响行数: ${deletedRows}`);
    } catch (error) {
      hilog.error(0xFF00, TAG, '删除截图失败: ' + JSON.stringify(error));
      throw new Error('删除截图失败');
    }
  }
}
