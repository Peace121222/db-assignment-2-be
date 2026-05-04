import {
  IsOptional,
  IsNumber,
  IsString,
  IsEnum,
  IsUUID,
} from 'class-validator';
import { Expose, Type } from 'class-transformer';

export enum SortByEnum {
  PRICE = 'price',
  NAME = 'name',
  CREATED_AT = 'created_at',
}

export enum SortOrderEnum {
  ASC = 'ASC',
  DESC = 'DESC',
}

export enum ProductStatusEnum {
  ACTIVE = 'active',
  OUT_OF_STOCK = 'out_of_stock',
  HIDDEN = 'hidden',
}

export class GetProductsRequestDto {
  @Expose()
  @IsOptional()
  @IsString()
  keyword?: string;

  @Expose()
  @IsOptional()
  @IsUUID('4')
  categoryId?: string;

  @Expose()
  @IsOptional()
  @IsUUID('4')
  storeId?: string;

  @Expose()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  minPrice?: number;

  @Expose()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  maxPrice?: number;

  @Expose()
  @IsOptional()
  @IsEnum(ProductStatusEnum)
  status?: 'active' | 'out_of_stock' | 'hidden';

  @Expose()
  @IsOptional()
  @IsEnum(SortByEnum)
  sortBy?: 'price' | 'name' | 'created_at';

  @Expose()
  @IsOptional()
  @IsEnum(SortOrderEnum)
  sortOrder?: 'ASC' | 'DESC';
}

export class GetProductsResponseDto {
  @Expose()
  product_id: string;

  @Expose()
  product_name: string;

  @Expose()
  category_name: string;

  @Expose()
  store_name: string;

  @Expose()
  base_price: string;

  @Expose()
  status: string;
}
