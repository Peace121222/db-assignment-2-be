export interface CreateProductInput {
  storeId: string;
  categoryId: string;
  name: string;
  description: string;
  basePrice: number;
}

export interface CreateProductResult {
  success: boolean;
  message: string;
  productId: string;
}
