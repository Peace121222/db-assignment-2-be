import { Injectable, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { GetStoreResult } from './interfaces/store.interface';

@Injectable()
export class StoresService {
  constructor(private readonly db: DatabaseService) {}

  async getStoreById(storeId: string): Promise<GetStoreResult> {
    const sql = `
  SELECT 
    s.store_id,
    s.store_name,
    u.phone,
    u.email,
    fn_Calculate_Store_Average_Rating(?) AS average_rating
  FROM STORE s
  JOIN USER_ACCOUNT u ON s.seller_id = u.account_id
  WHERE s.store_id = ?
`;

    const params = [storeId, storeId];
    const result = await this.db.query<GetStoreResult[]>(sql, params);

    if (!result || result.length === 0) {
      throw new NotFoundException('Không tìm thấy thông tin cửa hàng');
    }

    return result[0];
  }
}
