import { IsNotEmpty, IsNumber, IsString, IsUUID, Min } from 'class-validator';
import { Expose, Type } from 'class-transformer';

export class CreateProductRequestDto {
  @Expose()
  @IsNotEmpty({ message: 'Store ID không được để trống' })
  @IsUUID('4', { message: 'Store ID phải đúng định dạng UUID v4' })
  storeId: string;

  @Expose()
  @IsNotEmpty({ message: 'Category ID không được để trống' })
  @IsUUID('4', { message: 'Category ID phải đúng định dạng UUID v4' })
  categoryId: string;

  @Expose()
  @IsNotEmpty({ message: 'Tên sản phẩm không được để trống' })
  @IsString({ message: 'Tên sản phẩm phải là một chuỗi' })
  name: string;

  @Expose()
  @IsNotEmpty({ message: 'Mô tả không được để trống' })
  @IsString({ message: 'Mô tả phải là một chuỗi' })
  description: string;

  @Expose()
  @IsNotEmpty({ message: 'Giá sản phẩm không được để trống' })
  @Type(() => Number)
  @IsNumber({}, { message: 'Giá sản phẩm phải là một số' })
  @Min(0, { message: 'Giá sản phẩm không được nhỏ hơn 0' })
  basePrice: number;
}

export class CreateProductResponseDto {
  @Expose()
  success: boolean;

  @Expose()
  message: string;

  @Expose()
  productId: string;
}
