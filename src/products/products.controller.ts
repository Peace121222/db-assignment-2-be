import {
  Controller,
  Post,
  Delete,
  Body,
  Param,
  ValidationPipe,
  ParseUUIDPipe,
  Get,
  Query,
  Patch,
} from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { ProductsService } from './products.service';
import {
  CreateProductRequestDto,
  CreateProductResponseDto,
} from './dto/create-product.dto';
import {
  UpdateProductRequestDto,
  UpdateProductResponseDto,
  DeleteProductResponseDto,
} from './dto';
import { CreateProductInput, UpdateProductInput } from './interface';
import {
  GetProductsRequestDto,
  GetProductsResponseDto,
} from './dto/get-products.dto';
import { GetProductsFilterInput } from './interface/get-products.interface';

@Controller('products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @Post()
  async createProduct(
    @Body(new ValidationPipe({ transform: true }))
    requestDto: CreateProductRequestDto,
  ): Promise<CreateProductResponseDto> {
    const serviceInput: CreateProductInput = {
      storeId: requestDto.storeId,
      categoryId: requestDto.categoryId,
      name: requestDto.name,
      description: requestDto.description,
      basePrice: requestDto.basePrice,
    };

    const serviceResult =
      await this.productsService.createProduct(serviceInput);

    return plainToInstance(CreateProductResponseDto, serviceResult, {
      excludeExtraneousValues: true,
    });
  }

  @Patch(':id')
  async updateProduct(
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
    @Body(new ValidationPipe({ transform: true }))
    requestDto: UpdateProductRequestDto,
  ): Promise<UpdateProductResponseDto> {
    const serviceInput: UpdateProductInput = {
      storeId: requestDto.storeId,
      categoryId: requestDto.categoryId,
      name: requestDto.name,
      description: requestDto.description,
      basePrice: requestDto.basePrice,
      status: requestDto.status,
    };

    const serviceResult = await this.productsService.updateProduct(
      id,
      serviceInput,
    );

    return plainToInstance(UpdateProductResponseDto, serviceResult, {
      excludeExtraneousValues: true,
    });
  }

  @Delete(':id')
  async deleteProduct(
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ): Promise<DeleteProductResponseDto> {
    const serviceResult = await this.productsService.deleteProduct(id);

    return plainToInstance(DeleteProductResponseDto, serviceResult, {
      excludeExtraneousValues: true,
    });
  }

  @Get()
  async getProducts(
    @Query(new ValidationPipe({ transform: true }))
    requestDto: GetProductsRequestDto,
  ): Promise<GetProductsResponseDto[]> {
    const serviceInput: GetProductsFilterInput = {
      keyword: requestDto.keyword,
      categoryId: requestDto.categoryId,
      minPrice: requestDto.minPrice,
      maxPrice: requestDto.maxPrice,
      status: requestDto.status,
      sortBy: requestDto.sortBy,
      sortOrder: requestDto.sortOrder,
    };

    const serviceResult = await this.productsService.getProducts(serviceInput);

    return plainToInstance(GetProductsResponseDto, serviceResult, {
      excludeExtraneousValues: true,
    });
  }
}
