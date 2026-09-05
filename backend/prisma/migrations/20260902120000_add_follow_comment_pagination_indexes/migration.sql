-- DropIndex
DROP INDEX "comments_reply_to_id_idx";

-- DropIndex
DROP INDEX "follows_following_id_idx";

-- CreateIndex
CREATE INDEX "comments_reply_to_id_created_at_idx" ON "comments"("reply_to_id", "created_at");

-- CreateIndex
CREATE INDEX "follows_following_id_created_at_idx" ON "follows"("following_id", "created_at");

-- CreateIndex
CREATE INDEX "follows_follower_id_created_at_idx" ON "follows"("follower_id", "created_at");
