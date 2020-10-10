module ResultEnum
  extend ActiveSupport::Concern

  included do
    enum result: { pending: 0, win: 1, loss: 2, push: 3, canceled: 4 }
  end
end
