export abstract class BaseRepository<T> {
  protected model: any;

  constructor(model: any) {
    this.model = model;
  }

  async findById(id: string, tenant_id: string): Promise<T | null> {
    return this.model.findFirst({
      where: { id, tenant_id }
    });
  }

  async findAll(tenant_id: string, options: any = {}): Promise<T[]> {
    return this.model.findMany({
      where: { tenant_id, ...options.where },
      ...options
    });
  }

  async create(data: any, tenant_id: string): Promise<T> {
    return this.model.create({
      data: {
        ...data,
        tenant_id
      }
    });
  }

  async update(id: string, tenant_id: string, data: any): Promise<T> {
    return this.model.update({
      where: { id },
      data
    });
  }

  async delete(id: string, tenant_id: string): Promise<T> {
    return this.model.delete({
      where: { id }
    });
  }
}
