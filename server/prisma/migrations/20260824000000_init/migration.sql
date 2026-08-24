-- CreateEnum
CREATE TYPE "SplitType" AS ENUM ('even', 'custom', 'ratio');

-- CreateEnum
CREATE TYPE "Category" AS ENUM ('food', 'traffic', 'hotel', 'shopping', 'fun', 'other');

-- CreateEnum
CREATE TYPE "MemberStatus" AS ENUM ('active', 'left');

-- CreateEnum
CREATE TYPE "SettleStatus" AS ENUM ('pending', 'partial', 'settled');

-- CreateEnum
CREATE TYPE "SettlementStatus" AS ENUM ('pending', 'paid');

-- CreateEnum
CREATE TYPE "BillCycle" AS ENUM ('weekly', 'biweekly', 'monthly');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('new_bill', 'remind', 'invite', 'regular', 'settled');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "account_name" VARCHAR(32) NOT NULL,
    "nickname" VARCHAR(24) NOT NULL DEFAULT '',
    "avatar_url" TEXT,
    "bio" VARCHAR(50),
    "password_hash" VARCHAR(100) NOT NULL,
    "security_question" VARCHAR(100) NOT NULL,
    "security_answer_hash" VARCHAR(100) NOT NULL,
    "reset_token_hash" VARCHAR(100),
    "reset_token_expires_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "groups" (
    "id" UUID NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "avatar_url" TEXT,
    "intro" VARCHAR(100),
    "owner_id" UUID NOT NULL,
    "default_split_type" "SplitType" NOT NULL DEFAULT 'even',
    "invite_code" VARCHAR(12) NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "group_members" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "MemberStatus" NOT NULL DEFAULT 'active',
    "joined_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bills" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "creator_id" UUID NOT NULL,
    "payer_id" UUID NOT NULL,
    "title" VARCHAR(80) NOT NULL,
    "location" VARCHAR(120),
    "amount_cents" INTEGER NOT NULL,
    "bill_date" DATE NOT NULL,
    "category" "Category" NOT NULL,
    "split_type" "SplitType" NOT NULL,
    "settle_status" "SettleStatus" NOT NULL DEFAULT 'pending',
    "is_regular" BOOLEAN NOT NULL DEFAULT false,
    "regular_id" UUID,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "bills_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bill_participants" (
    "id" UUID NOT NULL,
    "bill_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "share_amount_cents" INTEGER NOT NULL,
    "exempt" BOOLEAN NOT NULL DEFAULT false,
    "paid" BOOLEAN NOT NULL DEFAULT false,
    "paid_at" TIMESTAMPTZ,
    "remind_count" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "bill_participants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "receipts" (
    "id" UUID NOT NULL,
    "bill_id" UUID NOT NULL,
    "object_key" TEXT NOT NULL,
    "sort" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "receipts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" VARCHAR(100) NOT NULL,
    "body" VARCHAR(300) NOT NULL,
    "ref_type" VARCHAR(32),
    "ref_id" UUID,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "regular_bills" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "creator_id" UUID NOT NULL,
    "title" VARCHAR(80) NOT NULL,
    "amount_cents" INTEGER NOT NULL,
    "category" "Category" NOT NULL,
    "split_type" "SplitType" NOT NULL,
    "cycle" "BillCycle" NOT NULL,
    "day_of_week" INTEGER,
    "day_of_month" INTEGER,
    "participants_template" JSONB NOT NULL,
    "next_run_at" TIMESTAMPTZ NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "regular_bills_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "settlements" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "from_user_id" UUID NOT NULL,
    "to_user_id" UUID NOT NULL,
    "amount_cents" INTEGER NOT NULL,
    "status" "SettlementStatus" NOT NULL DEFAULT 'pending',
    "bill_ids" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "settlements_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_account_name_key" ON "users"("account_name");

-- CreateIndex
CREATE UNIQUE INDEX "groups_invite_code_key" ON "groups"("invite_code");

-- CreateIndex
CREATE INDEX "groups_invite_code_idx" ON "groups"("invite_code");

-- CreateIndex
CREATE INDEX "group_members_user_id_idx" ON "group_members"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "group_members_group_id_user_id_key" ON "group_members"("group_id", "user_id");

-- CreateIndex
CREATE INDEX "bills_group_id_bill_date_idx" ON "bills"("group_id", "bill_date" DESC);

-- CreateIndex
CREATE INDEX "bills_creator_id_idx" ON "bills"("creator_id");

-- CreateIndex
CREATE INDEX "bills_payer_id_idx" ON "bills"("payer_id");

-- CreateIndex
CREATE INDEX "bills_regular_id_idx" ON "bills"("regular_id");

-- CreateIndex
CREATE INDEX "bill_participants_bill_id_idx" ON "bill_participants"("bill_id");

-- CreateIndex
CREATE INDEX "bill_participants_user_id_idx" ON "bill_participants"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "bill_participants_bill_id_user_id_key" ON "bill_participants"("bill_id", "user_id");

-- CreateIndex
CREATE INDEX "receipts_bill_id_idx" ON "receipts"("bill_id");

-- CreateIndex
CREATE INDEX "notifications_user_id_is_read_idx" ON "notifications"("user_id", "is_read");

-- CreateIndex
CREATE INDEX "notifications_user_id_idx" ON "notifications"("user_id");

-- CreateIndex
CREATE INDEX "regular_bills_next_run_at_idx" ON "regular_bills"("next_run_at");

-- CreateIndex
CREATE INDEX "regular_bills_group_id_idx" ON "regular_bills"("group_id");

-- CreateIndex
CREATE INDEX "settlements_group_id_idx" ON "settlements"("group_id");

-- AddForeignKey
ALTER TABLE "groups" ADD CONSTRAINT "groups_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bills" ADD CONSTRAINT "bills_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bills" ADD CONSTRAINT "bills_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bills" ADD CONSTRAINT "bills_payer_id_fkey" FOREIGN KEY ("payer_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bill_participants" ADD CONSTRAINT "bill_participants_bill_id_fkey" FOREIGN KEY ("bill_id") REFERENCES "bills"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bill_participants" ADD CONSTRAINT "bill_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "receipts" ADD CONSTRAINT "receipts_bill_id_fkey" FOREIGN KEY ("bill_id") REFERENCES "bills"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "regular_bills" ADD CONSTRAINT "regular_bills_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "regular_bills" ADD CONSTRAINT "regular_bills_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "settlements" ADD CONSTRAINT "settlements_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "settlements" ADD CONSTRAINT "settlements_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "settlements" ADD CONSTRAINT "settlements_to_user_id_fkey" FOREIGN KEY ("to_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

