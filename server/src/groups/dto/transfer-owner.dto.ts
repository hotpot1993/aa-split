import { IsUUID } from 'class-validator';

export class TransferOwnerDto {
  @IsUUID()
  newOwnerId!: string;
}
