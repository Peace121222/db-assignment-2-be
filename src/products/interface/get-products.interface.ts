export interface GetProductsFilterInput {
  keyword?: string;
  categoryId?: string;
  storeId?: string;
  minPrice?: number;
  maxPrice?: number;
  status?: 'active' | 'out_of_stock' | 'hidden';
  sortBy?: 'price' | 'name' | 'created_at';
  sortOrder?: 'ASC' | 'DESC';
}

export interface ProductResponseItem {
  product_id: string;
  product_name: string;
  description: string; // <-- Thêm trường này
  category_id: string; // <-- Thêm trường này
  category_name: string;
  store_id: string; // <-- Thêm trường này
  store_name: string;
  base_price: string;
  status: string;
}
