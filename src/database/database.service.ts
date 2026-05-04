import {
  Injectable,
  OnModuleInit,
  OnModuleDestroy,
  Logger,
} from '@nestjs/common';
import { createPool, Pool } from 'mysql2/promise';
import process from 'process';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private pool!: Pool;
  private readonly logger = new Logger(DatabaseService.name);

  async onModuleInit(): Promise<void> {
    try {
      this.pool = createPool({
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 3306,
        user: process.env.DB_USER || 'root',
        password: process.env.DB_PASSWORD || '',
        database: process.env.DB_NAME || 'db_assignment_2',
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
      });

      const connection = await this.pool.getConnection();
      this.logger.log('🔥 Kết nối MySQL (Shopee Pro Max) thành công!');
      connection.release();
    } catch (error: unknown) {
      if (error instanceof Error) {
        this.logger.error(
          `❌ Lỗi kết nối MySQL: ${error.message}`,
          error.stack,
        );
      } else {
        this.logger.error('❌ Lỗi kết nối MySQL không xác định', String(error));
      }
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
      this.logger.log('💤 Đã ngắt kết nối MySQL.');
    }
  }

  async query<T>(sql: string, values?: any[]): Promise<T> {
    const [rows] = await this.pool.query(sql, values);
    return rows as T;
  }
}
