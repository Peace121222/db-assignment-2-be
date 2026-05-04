export interface UpdateProductInput {
  storeId?: string;
  categoryId?: string;
  name?: string;
  description?: string;
  basePrice?: number;
  status?: 'active' | 'out_of_stock' | 'hidden';
}

export interface UpdateProductResult {
  success: boolean;
  message: string;
}
