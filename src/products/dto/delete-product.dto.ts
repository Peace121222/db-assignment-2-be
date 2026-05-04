import { Expose } from 'class-transformer';

export class DeleteProductResponseDto {
  @Expose()
  success: boolean;

  @Expose()
  message: string;
}
