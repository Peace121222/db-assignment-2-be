import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { StoresService } from './stores.service';
import { GetStoreResponseDto } from './dto/get-store.dto';

@Controller('stores')
export class StoresController {
  constructor(private readonly storesService: StoresService) {}

  @Get(':id')
  async getStore(
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ): Promise<GetStoreResponseDto> {
    const serviceResult = await this.storesService.getStoreById(id);

    return plainToInstance(GetStoreResponseDto, serviceResult, {
      excludeExtraneousValues: true,
    });
  }
}
