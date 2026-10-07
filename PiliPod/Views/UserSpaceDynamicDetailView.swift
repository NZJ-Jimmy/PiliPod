import SwiftUI

struct UserSpaceDynamicDetailView: View {
    let item: UserSpaceDynamicItem
    let onVideoTap: (UserSpaceDynamicItem.Video) -> Void
    let onLiveTap: (UserSpaceDynamicItem.Live) -> Void
    let onAuthorTap: (Int) -> Void
    var transitionNamespace: Namespace.ID? = nil
    var onPreviewTap: ((UserSpaceDynamicItem.PreviewCard) -> Void)? = nil

    private var commentOID: Int64? {
        let value = item.commentTarget.resourceID ?? item.commentTarget.commentID
        return value.flatMap(Int64.init)
    }

    private var commentType: Int {
        item.commentTarget.type ?? 17
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                detailCard

                if let oid = commentOID, oid > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("评论")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 16)
                        VideoCommentsTabView(
                            oid: oid,
                            commentType: commentType,
                            onOpenUserSpace: onAuthorTap,
                            allowsPosting: false,
                            isEmbedded: true
                        )
                    }
                    .padding(.top, 12)
                } else {
                    Text("暂无评论")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("动态详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var detailCard: some View {
        let card = DynamicCardView(
            item: item,
            onVideoTap: onVideoTap,
            onLiveTap: onLiveTap,
            onAuthorTap: onAuthorTap,
            onCommentTap: { _ in },
            showsFullTextByDefault: true,
            videoSourcePrefix: "dynamicDetail",
            onPreviewTap: onPreviewTap,
            transitionNamespace: transitionNamespace
        )
        if let transitionNamespace {
            card.matchedTransitionSource(id: "dynamicDetail.\(item.id)", in: transitionNamespace)
        } else {
            card
        }
    }
}
