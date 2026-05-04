import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';
import { Expose, Type } from 'class-transformer';

export class UpdateProductRequestDto {
  @Expose()
  @IsOptional()
  @IsUUID('4', { message: 'Store ID phải đúng định dạng UUID v4' })
  storeId?: string;

  @Expose()
  @IsOptional()
  @IsUUID('4', { message: 'Category ID phải đúng định dạng UUID v4' })
  categoryId?: string;

  @Expose()
  @IsOptional()
  @IsString({ message: 'Tên sản phẩm phải là một chuỗi' })
  name?: string;

  @Expose()
  @IsOptional()
  @IsString({ message: 'Mô tả phải là một chuỗi' })
  description?: string;

  @Expose()
  @IsOptional()
  @Type(() => Number)
  @IsNumber({}, { message: 'Giá sản phẩm phải là một số' })
  @Min(0, { message: 'Giá sản phẩm không được nhỏ hơn 0' })
  basePrice?: number;

  @Expose()
  @IsOptional()
  @IsEnum(['active', 'out_of_stock', 'hidden'], {
    message: 'Trạng thái không hợp lệ',
  })
  status?: 'active' | 'out_of_stock' | 'hidden';
}

export class UpdateProductResponseDto {
  @Expose()
  success: boolean;

  @Expose()
  message: string;
}
