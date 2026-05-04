import { Expose, Type } from 'class-transformer';

export class GetStoreResponseDto {
  @Expose()
  store_id!: string;

  @Expose()
  store_name!: string;

  @Expose()
  phone!: string;

  @Expose()
  email!: string;

  @Expose()
  address!: string;

  @Expose()
  @Type(() => Number)
  average_rating!: number;
}
