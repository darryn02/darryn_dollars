module Md5Digestible
  extend ActiveSupport::Concern

  included do
    before_save :set_md5_digest
  end

  class_methods do
    def find_or_create_unique_with_md5_digest(attrs)
      md5_digest = new(attrs).compute_md5_digest

      find_by(md5_digest: md5_digest) || transaction(requires_new: true) do
        create!(attrs)
      end
    rescue ActiveRecord::RecordNotUnique
      find_by!(md5_digest: md5_digest)
    end
  end

  def compute_md5_digest
    Digest::MD5.hexdigest(digestible_attribute_string)
  end

  private

  def set_md5_digest
    self.md5_digest = compute_md5_digest
  end

  def digestible_attribute_string
    digestible_attributes.
      map { |att| "#{att}\uffef#{send(att)}" }.
      join("\uffff")
  end

  # the attributes over which we want records to be unique
  def digestible_attributes
    raise "Including class must override"
  end
end
