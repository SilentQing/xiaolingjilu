import relationalStore from '@ohos.data.relationalStore';
import UIAbility from '@ohos.app.ability.UIAbility';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Category, RecordItemData } from '../model/RecordItemData';

export class RdbManager {
  private static instance: RdbManager;
  private rdbStore: relationalStore.RdbStore | null = null;

  // 数据库配置
  private static readonly STORE_CONFIG: relationalStore.StoreConfig = {
    name: 'XiaoLingRecord.db', // 数据库文件名
    securityLevel: relationalStore.SecurityLevel.S1 // 安全级别
  };

  // 建表 SQL 语句
  private static readonly SQL_CREATE_TABLE = `
    CREATE TABLE IF NOT EXISTS record_item (
      id TEXT PRIMARY KEY,
      image_path TEXT,
      title TEXT,
      summary TEXT,
      category TEXT,
      tags TEXT,
      highlight_value TEXT,
      create_time INTEGER,
      embedding TEXT
    )
  `;

  // 单例模式
  public static getInstance(): RdbManager {
    if (!RdbManager.instance) {
      RdbManager.instance = new RdbManager();
    }
    return RdbManager.instance;
  }

  /**
   * 初始化数据库在 EntryAbility 的 onCreate 中调用
   * @param context 应用上下文
   */
  public async initRdb(context: Context): Promise<void> {
    try {
      this.rdbStore = await relationalStore.getRdbStore(context, RdbManager.STORE_CONFIG);
      hilog.info(0x0000, 'RdbManager', '数据库连接成功');

      // 执行建表语句
      await this.rdbStore.executeSql(RdbManager.SQL_CREATE_TABLE);
      hilog.info(0x0000, 'RdbManager', '表结构初始化完成');

    } catch (err) {
      hilog.error(0x0000, 'RdbManager', `数据库初始化失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 获取数据库实例，供增删改查方法使用
   */
  public getStore(): relationalStore.RdbStore {
    if (!this.rdbStore) {
      throw new Error('RdbStore 未初始化，请先调用 initRdb');
    }
    return this.rdbStore;
  }

  /**
   * 插入一条新记录
   * @param item 从 UI 传入的记录数据对象
   * @returns 返回插入成功的行 ID（若失败则抛出异常）
   */
  public async insertRecord(item: RecordItemData): Promise<number> {
    const store = this.getStore();

    // 将前端的数据模型映射为数据库认识的 ValuesBucket
    const valueBucket: relationalStore.ValuesBucket = {
      'id': item.id,
      'image_path': item.imagePath,
      'title': item.title,
      'summary': item.summary,
      'category': item.category,
      // SQLite 没有数组类型，我们将 tags 数组转为 JSON 字符串存储
      'tags': JSON.stringify(item.tags || []),
      'highlight_value': item.highlightValue || '',
      // 将字符串时间转换为毫秒时间戳存储，方便后续按时间排序
      'create_time': new Date(item.createTime).getTime(),
      'embedding' : item.embedding ? JSON.stringify(item.embedding) : '[]'
    };

    // 执行插入操作
    const rowId = await store.insert('record_item', valueBucket);
    return rowId;
  }

  /**
   * 查询记录列表（支持按分类或关键词过滤）
   * @param category 可选：分类（如 Category.Bill）
   * @param keyword 可选：搜索关键词
   * @returns 封装好的记录数组
   */
  public async queryRecords(category?: string, keyword?: string): Promise<RecordItemData[]> {
    const store = this.getStore();
    let predicates = new relationalStore.RdbPredicates('record_item');     // 初始化查询条件构造器

    if (category) predicates.equalTo('category', category);                // 如果传了分类，则只查该分类（对应列表页顶部的 Tab 切换）
    // 如果传了关键词，则进行模糊搜索（对应搜索页的边输边搜）
    if (keyword) {
      // 标题或摘要包含关键词即可
      predicates.like('title', `%${keyword}%`).or().like('summary', `%${keyword}%`);
    }
    predicates.orderByDesc('create_time');                                 // 默认按创建时间倒序排列（最新的在最上面）

    // 执行查询，返回 ResultSet 结果集
    let resultSet = await store.query(predicates, [
      'id', 'image_path', 'title', 'summary', 'category', 'tags', 'highlight_value', 'create_time', 'embedding'
    ]);

    let results: RecordItemData[] = [];

    // 遍历结果集，逐行解析数据
    while (resultSet.goToNextRow()) {
      let embeddingArray: number[] = [];
      const embeddingStr = resultSet.getString(resultSet.getColumnIndex('embedding'));

      if (embeddingStr) {
        try {
          // 将 "[0.12, -0.45, ...]" 字符串还原为真正的数组
          embeddingArray = JSON.parse(embeddingStr);
        } catch (e) {
          console.error('向量 JSON 解析失败，跳过该字段', e);
        }
      }

      results.push({
        id: resultSet.getString(resultSet.getColumnIndex('id')),
        imagePath: resultSet.getString(resultSet.getColumnIndex('image_path')),
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        summary: resultSet.getString(resultSet.getColumnIndex('summary')),
        category: resultSet.getString(resultSet.getColumnIndex('category')) as Category,
        // 将存进去的 JSON 字符串反解析回数组
        tags: JSON.parse(resultSet.getString(resultSet.getColumnIndex('tags')) || '[]'),
        highlightValue: resultSet.getString(resultSet.getColumnIndex('highlight_value')),
        // 将毫秒时间戳还原为本地日期字符串供 UI 显示
        createTime: new Date(resultSet.getLong(resultSet.getColumnIndex('create_time'))).toLocaleString(),
        embedding: embeddingArray
      });
    }

    resultSet.close();

    return results;
  }


  /**
   * 根据 ID 删除单条记录
   * @param id 记录的唯一标识
   * @returns 受影响的行数 (1 表示成功)
   */
  public async deleteRecord(id: string): Promise<number> {
    const store = this.getStore();

    // 构造删除条件：WHERE id = ?
    let predicates = new relationalStore.RdbPredicates('record_item');
    predicates.equalTo('id', id);

    // 执行删除操作
    const deletedRows = await store.delete(predicates);
    return deletedRows;
  }

}

