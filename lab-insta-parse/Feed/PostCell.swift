//
//  PostCell.swift
//  lab-insta-parse
//
//  Created by Charlie Hieger on 11/3/22.
//

import UIKit
import Alamofire
import AlamofireImage
import CoreLocation
import ParseSwift

class PostCell: UITableViewCell {

    @IBOutlet private weak var usernameLabel: UILabel!
    @IBOutlet private weak var postImageView: UIImageView!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet private weak var blurView: UIVisualEffectView!
    @IBOutlet private weak var commentsLabel: UILabel!
    @IBOutlet private weak var commentTextField: UITextField!
    @IBOutlet private weak var commentButton: UIButton!

    private var imageDataRequest: DataRequest?
    private var comments: [Comment] = []
    private var currentPost: Post?

    override func awakeFromNib() {
        super.awakeFromNib()
        commentsLabel.numberOfLines = 0
    }

    func configure(with post: Post) {
        currentPost = post
        commentTextField.text = ""

        // Username
        usernameLabel.text = post.user?.username

        // Caption
        captionLabel.text = post.caption

        // Image
        if let imageFile = post.imageFile, let imageUrl = imageFile.url {
            imageDataRequest?.cancel()
            imageDataRequest = AF.request(imageUrl).responseImage { [weak self] response in
                guard let self else { return }
                // Ensure we're still configuring same post (cell may have been reused)
                guard self.currentPost?.objectId == post.objectId else { return }

                if case .success(let image) = response.result {
                    self.postImageView.image = image
                }
            }
        }

        // Date + location
        if let date = post.createdAt {
            let baseDateText = DateFormatter.postFormatter.string(from: date)
            dateLabel.text = baseDateText

            if let lat = post.latitude, let lon = post.longitude {
                let location = CLLocation(latitude: lat, longitude: lon)
                let postId = post.objectId

                CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
                    guard let self else { return }
                    guard self.currentPost?.objectId == postId else { return }

                    var locationText = ""
                    if let place = placemarks?.first {
                        let city = place.locality ?? ""
                        let state = place.administrativeArea ?? ""
                        if !city.isEmpty && !state.isEmpty {
                            locationText = " • 📍 \(city), \(state)"
                        }
                    }

                    DispatchQueue.main.async {
                        self.dateLabel.text = baseDateText + locationText
                    }
                }
            }
        }

        // Blur logic
        if let currentUser = User.current,
           let lastPostedDate = currentUser.lastPostedDate,
           let postCreatedDate = post.createdAt,
           let diffHours = Calendar.current.dateComponents([.hour], from: postCreatedDate, to: lastPostedDate).hour {
            blurView.isHidden = abs(diffHours) < 24
        } else {
            blurView.isHidden = false
        }

        // Load comments for this post
        loadComments()
    }

    private func loadComments() {
        guard let post = currentPost else { return }
        let postId = post.objectId

        guard let query = try? Comment.query()
            .where("post" == post)
            .include("user")
            .order([.ascending("createdAt")]) else {
                return
        }

        query.find { [weak self] result in
            guard let self else { return }
            guard self.currentPost?.objectId == postId else { return }

            switch result {
            case .success(let comments):
                self.comments = comments
                self.updateCommentsLabel()
            case .failure(let error):
                print("Error loading comments:", error.localizedDescription)
            }
        }
    }

    private func updateCommentsLabel() {
        let text = comments.compactMap { comment -> String? in
            guard let username = comment.user?.username,
                  let body = comment.text else { return nil }
            return "\(username): \(body)"
        }.joined(separator: "\n")

        DispatchQueue.main.async {
            self.commentsLabel.text = text
        }
    }

    @IBAction private func onCommentButtonTapped(_ sender: Any) {
        guard let text = commentTextField.text,
              !text.isEmpty,
              let post = currentPost,
              let currentUser = User.current else { return }

        var comment = Comment()
        comment.text = text
        comment.user = currentUser
        comment.post = post

        comment.save { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.commentTextField.text = ""
                }
                self.loadComments()
            case .failure(let error):
                print("Error saving comment:", error.localizedDescription)
            }
        }
    }
    @IBAction func onTapped(_ sender: Any) {
    }
    @IBAction func OnCommentButtonTapped(_ sender: Any) {
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()

        imageDataRequest?.cancel()
        postImageView.image = nil

        currentPost = nil
        comments = []
        commentsLabel.text = ""
        commentTextField.text = ""
        dateLabel.text = nil
        captionLabel.text = nil
        usernameLabel.text = nil
    }
}
