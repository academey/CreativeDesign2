require 'rubygems'
require 'engtagger'
require 'nokogiri'

# Create a parser object
class WordNode
	def initialize(tg,wd)
		@tag = tg
		@word = wd
	end
end
class ProblemMaker
	def initialize
		@@tgr = EngTagger.new
	end
	def input(text)
		@plainText = text
		tagged = @@tgr.add_tags(text)
		taggedArray = tagged.split
		# convert one dimension info to two dimension. 
		@tagged2DArray = Array.new { Array.new }

		lineNum = 0
		wordIndex = 0
		taggedArray.each do |word|
			tagl = word.index('<')
			tagr = word.index('>')
			tag = word[tagl + 1, tagr - tagl - 1]
			if tag == 'pp'
				lineNum = lineNum + 1
			end
			nextTagl = word.rindex('<')
			wd = word[tagr + 1, nextTagl - tagr - 1]
			wNode = WordNode(tag, wd) 
		
			@tagged2DArray = Array.new { Array.new }
			lineArray = @tagged2DArray[lineNum]
			lineArray[wordIndex] = wNode
			wordIndex = wordIndex + 1 
		end
	end
	def caseParsing		
		@tagged2DArray.each do |lineArray|
			print 2			
		end
	end
	
	def problemMaker
	end
	def posTagging
	end	

end
# Sample text
text = "Alice chased the big fat cat."
test = %q[ "'"""''''sd'''ruby test ]
text = %q[what are you talking about? I see what you]

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
