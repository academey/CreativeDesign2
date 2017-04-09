class Word < ActiveRecord::Base
	enum target: {mid_1: 0, mid_2: 1, mid_3: 2, high_c: 3, high_1: 4, high_2: 5}
	enum priority: {normal: 0, little: 1, very: 2}
	validates :name, :presence => true
	validates :meaning, :presence => true
	validates :pos, :presence => true

end
