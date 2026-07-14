import Foundation

enum FollowUpTranscript {
    static func appending(question: String, to transcript: String) -> String {
        """
        \(transcript)

        ---

        ## 追问

        **问题：** \(question)

        **回答：**
        """
    }
}
