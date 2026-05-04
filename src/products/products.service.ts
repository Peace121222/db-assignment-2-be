import { Injectable, BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { randomUUID } from 'crypto';
import {
  CreateProductInput,
  CreateProductResult,
  UpdateProductInput,
  UpdateProductResult,
  DeleteProductResult,
} from './interface';
import {
  GetProductsFilterInput,
  ProductResponseItem,
} from './interface/get-products.interface';

interface MySQLError extends Error {
  sqlState?: string;
  code?: string;
}

@Injectable()
export class ProductsService {
  constructor(private readonly db: DatabaseService) {}

  async createProduct(input: CreateProductInput): Promise<CreateProductResult> {
    const newProductId = randomUUID();
    const sql = `CALL sp_Insert_Product(?, ?, ?, ?, ?, ?)`;
    const params = [
      newProductId,
      input.storeId,
      input.categoryId,
      input.name,
      input.description,
      input.basePrice,
    ];

    try {
      await this.db.query(sql, params);
      return {
        success: true,
        message: 'Tạo sản phẩm thành công',
        productId: newProductId,
      };
    } catch (error: unknown) {
      const mysqlError = error as MySQLError;
      if (mysqlError.sqlState === '45000') {
        throw new BadRequestException(mysqlError.message);
      }
      throw new BadRequestException(
        `Lỗi khi tạo sản phẩm: ${mysqlError.message || 'Lỗi không xác định'}`,
      );
    }
  }

  async updateProduct(
    productId: string,
    input: UpdateProductInput,
  ): Promise<UpdateProductResult> {
    const sql = `CALL sp_Update_Product(?, ?, ?, ?, ?, ?, ?)`;
    const params = [
      productId,
      input.storeId ?? null,
      input.categoryId ?? null,
      input.name ?? null,
      input.description ?? null,
      input.basePrice ?? null,
      input.status ?? null,
    ];

    try {
      await this.db.query(sql, params);
      return {
        success: true,
        message: 'Cập nhật sản phẩm thành công',
      };
    } catch (error: unknown) {
      const mysqlError = error as MySQLError;
      if (mysqlError.sqlState === '45000') {
        throw new BadRequestException(mysqlError.message);
      }
      throw new BadRequestException(
        `Lỗi khi cập nhật sản phẩm: ${mysqlError.message || 'Lỗi không xác định'}`,
      );
    }
  }

  async deleteProduct(productId: string): Promise<DeleteProductResult> {
    const sql = `CALL sp_delete_product(?)`;
    const params = [productId];

    try {
      await this.db.query(sql, params);
      return {
        success: true,
        message: 'Xóa sản phẩm thành công',
      };
    } catch (error: unknown) {
      const mysqlError = error as MySQLError;
      if (mysqlError.sqlState === '45000') {
        throw new BadRequestException(mysqlError.message);
      }
      throw new BadRequestException(
        `Lỗi khi xóa sản phẩm: ${mysqlError.message || 'Lỗi không xác định'}`,
      );
    }
  }

  async getProducts(
    input: GetProductsFilterInput,
  ): Promise<ProductResponseItem[]> {
    const keyword = input.keyword || null;
    const categoryId = input.categoryId || null;
    const minPrice = input.minPrice ?? null;
    const maxPrice = input.maxPrice ?? null;
    const status = input.status || null;
    const sortBy = input.sortBy || 'created_at';
    const sortOrder = input.sortOrder || 'DESC';

    const sql = `CALL sp_Get_Products_By_Filter(?, ?, ?, ?, ?, ?, ?)`;
    const params = [
      keyword,
      categoryId,
      minPrice,
      maxPrice,
      status,
      sortBy,
      sortOrder,
    ];

    const result = await this.db.query<ProductResponseItem[][]>(sql, params);
    return result[0];
  }
}
