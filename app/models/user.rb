class User < ActiveRecord::Base
  include BCrypt

  has_secure_password

  attr_accessor :remember_token, :activation_token, :reset_token

  VALID_EMAIL_REGEX = /\A([\w+\-.]?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i

  has_one :role
  has_many :team_users
  has_many :teams, through: :team_users

  before_create :create_activation_digest
  before_create :generate_authentication_token

  before_save { self.email = email.downcase }

  validates :email, presence: true, length: { maximum: 50 },
                    format: { with: VALID_EMAIL_REGEX },
                    uniqueness: { case_sensitive: false }

  validates :password, presence: true, length: { maximum: 50, minimum: 8 }
  validates :reset_password_token, length: { maximum: 255 }

  def access_token
    access_tokens.active.first
  end

  # Activates an account.
  def activate
    update_attribute(:activated,    true)
    update_attribute(:activated_at, Time.zone.now)
  end

  # Returns true if the given token matches the digest.
  def authenticated?(attribute, token)
    digest = send("#{attribute}_digest")
    return false if digest.nil?
    BCrypt::Password.new(digest).is_password?(token)
  end

  # Sets the password reset attributes.
  def create_reset_digest
    self.reset_token = User.new_token
    update_attribute(:reset_digest, User.digest(reset_token))
    update_attribute(:reset_sent_at, Time.zone.now)
  end

  def forget
    update_attribute(:remember_digest, nil)
  end

  def password_reset_expired?
    reset_sent_at < 2.hours.ago
  end

  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  def register
    if valid?
      user = find_or_create_user
      if existing_user.present? && !existing_user.partially_registered
        UserActivationMailer.invite_existing_user(user).deliver_now
      else
        UserActivationMailer.invite_new_user(user).deliver_now
      end
    end
  end

  def request_password_reset
    self.reset_password_sent_at = Time.now
    self.reset_password_token = generate_reset_password_token
    save
  end

  def send_activation_email
    UserActivationMailer.account_activation(self).deliver_now
  end

  def send_password_reset_email
    PasswordMailer.reset_password(self).deliver_now
  end

  def User.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
                                                  BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
  end

  def User.new_token
    SecureRandom.urlsafe_base64
  end


  private

  def create_activation_digest
    self.activation_token  = User.new_token
    self.activation_digest = User.digest(activation_token)
  end

  def generate_authentication_token
    loop do
      self.authentication_token = SecureRandom.base64(64)
      break unless User.find_by(authentication_token: authentication_token)
    end
  end

  def generate_reset_password_token
    loop do
      token = User.new_token
      break token unless User.where(reset_password_token: token).exists?
    end
  end
end
