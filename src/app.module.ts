import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ProductsModule } from './products/products.module';
import { StoresModule } from './stores/stores.module';
import { DatabaseModule } from './database/database.module';

@Module({
  imports: [ProductsModule, StoresModule, DatabaseModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
