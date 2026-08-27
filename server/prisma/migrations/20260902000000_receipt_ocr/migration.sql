-- CreateEnum
CREATE TYPE "OcrStatus" AS ENUM ('pending', 'processing', 'success', 'failed');

-- CreateEnum
CREATE TYPE "ReceiptUploadStatus" AS ENUM ('pending', 'bound', 'expired');

-- AlterTable
ALTER TABLE "receipts" ADD COLUMN "amount_cents" INTEGER,
ADD COLUMN "confidence" DOUBLE PRECISION,
ADD COLUMN "currency" TEXT,
ADD COLUMN "ocr_status" "OcrStatus" NOT NULL DEFAULT 'pending',
ADD COLUMN "ocr_error" TEXT,
ADD COLUMN "ocr_attempts" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "receipt_uploads" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "object_key" TEXT NOT NULL,
    "status" "ReceiptUploadStatus" NOT NULL DEFAULT 'pending',
    "amount_cents" INTEGER,
    "confidence" DOUBLE PRECISION,
    "currency" TEXT,
    "ocr_status" "OcrStatus" NOT NULL DEFAULT 'pending',
    "ocr_error" TEXT,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "receipt_uploads_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "receipt_uploads_user_id_status_idx" ON "receipt_uploads"("user_id", "status");

-- CreateIndex
CREATE INDEX "receipt_uploads_expires_at_idx" ON "receipt_uploads"("expires_at");

-- AddForeignKey
ALTER TABLE "receipt_uploads" ADD CONSTRAINT "receipt_uploads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
