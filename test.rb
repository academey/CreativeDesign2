require 'rubygems'
require 'engtagger'
require 'nokogiri'

# Create a parser object
class WordNode
	def initialize(tg,wd,li,wi)
		@tag = tg
		@word = wd
		@line = li
		@wordIndex = wi
	end
end
class Problem
	def initalize(ty, answerList)
		@type = ty
		@answerList = answerList
	end
	def print
	
	end
end
class ProblemMaker
	def initialize
		@@tgr = EngTagger.new
	end
	def input(text)
		@plainText = text
		# add tag to each word.
		tagged = @@tgr.add_tags(text)
		taggedArray = tagged.split

		# convert one dimension info to two dimension. 
		@tagged2DArray = Array.new { Array.new }
		@tagCountList = Hash.new
		lineNum = 0
		wordIndex = 0
		taggedArray.each do |word|
			tagl = word.index('<')
			tagr = word.index('>')
			tag = word[tagl + 1, tagr - tagl - 1]
			nextTagl = word.rindex('<')
			wd = word[tagr + 1, nextTagl - tagr - 1]
			wNode = WordNode(tag, wd, lineNum, wordIndex) 
		
			# storing tag to 2D Array
			@tagged2DArray = Array.new { Array.new }
			lineArray = @tagged2DArray[lineNum]
			lineArray[wordIndex] = wNode

			# storing tag num.
			if @tagCountList[tag]['count'] == nil
				@tagCountList[tag]['count'] = 1
				@tagCountList[tag]['words'] = [wNode]
			else
				@tagCountList[tag]['count'] = @tagNumList + 1
				@tagCountList[tag]['words'] << wNode
			end

			wordIndex = wordIndex + 1 
			if tag == 'pp'
				lineNum = lineNum + 1
			end

		end
	end
		# by using each tag Count, suggest the problem making case.
	def caseParsing		
		if @tagCountList['CC']['count'] > 0
			print "test"
		end
		if @tagCountList
	end
	
	def problemMaker
		
	end

end
# Sample text
text = "Alice chased the big fat cat."
test = %q[ "'"""''''sd'''ruby test ]
text = %q[what are you talking about? I see what you]
testText = %q[Mathematics will attract those it can attract, but it will do nothing to overcome the resistance to science. Science is universal in principle but in practice it speaks to very few. Mathematics may be considered a communication skill of the highest type, frictionless so to speak; and at the opposite pole from mathematics, the fruits of science show the practical benefits of science without the use of words. But as we have seen, those fruits are ambivalent. Science as science does not speak; ideally, all scientific concepts are mathematized when scientists communicate with on e another, and when science displays its products to non-scientists it need not, and indeed is not able to, resort to salesmanship. When science speaks to others it is no longer science, and the scientist becomes or has to hire a publicist who dilutes the exactness of mathematics. In doing so the scientist reverses his drive toward mathematical exactness in favor of rhetorical vagueness and metaphor, thus violating the code of intellectual conduct that defines him as a scientist.]
tgr = EngTagger.new
# Add part-of-speech tags to text
tagged = tgr.add_tags(text)
print(tagged)
#=> "<nnp>Alice</nnp> <vbd>chased</vbd> <det>the</det> <jj>big</jj> <jj>fat</jj><nn>cat</nn> <pp>.</pp>"

# Get a list of all nouns and noun phrases with occurrence counts
word_list = tgr.get_words(text)

#=> {"Alice"=>1, "cat"=>1, "fat cat"=>1, "big fat cat"=>1}

# Get a readable version of the tagged text
readable = tgr.get_readable(text)

#=> "Alice/NNP chased/VBD the/DET big/JJ fat/JJ cat/NN ./PP"

# Get all nouns from a tagged output
nouns = tgr.get_nouns(tagged)

#=> {"cat"=>1, "Alice"=>1}

# Get all proper nouns
proper = tgr.get_proper_nouns(tagged)

#=> {"Alice"=>1}

# Get all past tense verbs
pt_verbs = tgr.get_past_tense_verbs(tagged)

#=> {"chased"=>1}

# Get all the adjectives
adj = tgr.get_adjectives(tagged)

#=> {"big"=>1, "fat"=>1}

# Get all noun phrases of any syntactic level
# (same as word_list but take a tagged input)
nps = tgr.get_noun_phrases(tagged)
print(nps)
#=> {"Alice"=>1, "cat"=>1, "fat cat"=>1, "big fat cat"=>1}
