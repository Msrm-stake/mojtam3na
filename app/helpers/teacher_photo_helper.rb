module TeacherPhotoHelper
  # The round portrait of a teacher: the approved photo, otherwise the avatar that matches the gender on the
  # profile, otherwise the first letter of the first name (what the site showed before photos existed).
  def teacher_portrait(profile, size: :card, extra_class: nil)
    frame = ["tphoto", "tphoto--#{size}", extra_class].compact.join(" ")
    name = public_name(profile.user)

    if profile.photo.attached?
      content_tag(:span, class: frame) do
        image_tag(teacher_photo_path(profile, v: profile.photo.blob.id), alt: name, width: 240, height: 240,
                                                                          loading: "lazy", decoding: "async", class: "tphoto__img")
      end
    elsif %w[female male].include?(profile.gender)
      content_tag(:span, render("teacher_profiles/avatar", kind: profile.gender),
                  class: "#{frame} tphoto--avatar", role: "img", "aria-label": name)
    else
      content_tag(:span, profile.user.first_name.to_s[0].to_s.upcase, class: "#{frame} tphoto--letter", "aria-hidden": "true")
    end
  end
end
