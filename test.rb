#!/usr/bin/env ruby
require 'rubygems'
require 'engtagger'
require 'nokogiri'
require 'httparty'
require 'json'
require 'set'


# for having two selections.
class Triple
  attr_accessor :one, :two, :three
  def set(param, data)
    case param
      when 0
        @one = data
      when 1
        @two = data
      when 2
        @three = data
    end
  end
end

# for making random set
def rand_n(n, max)
  randoms = Set.new
  loop do
    randoms << rand(max)
    return randoms.to_a if randoms.size >= n
  end
end


# Create a parser object
class WordNode
  attr_accessor :tag, :wd, :li,:wi
	def initialize(tag,wd,li,wi)
		@tag = tag
		@wd = wd
		@li = li
		@wi = wi
	end
end


class Candidate
	def initialize(cand, li, wi)
		@candidate = cand
		@lineIndex = li
		@wordIndex = wi
	end
	def cd
		@candidate
	end
	def li
		@lineIndex
	end
	def wi
		@wordIndex
	end
end


class WordAPI
  def initialize
		# uri for verb conjugation
    @@c_origin = "http://api.ultralingua.com/api"
    @@api_key = "273ac3536af7a7075481145554dcb92d"
		# uri for adjective
		@@a_origin = "http://api.datamuse.com/words"
	end

	def verbConjugation(verb, tense)
		uri = @@c_origin + '/conjugations' +'/eng/' + verb + '?tense=' + tense
    puts(uri)
		response = HTTParty.get(uri)
    jsonHash = JSON.parse(response.body)
    return jsonHash[0]['surfaceform']
  end
  def tenseChange(verb, tense)
    return "" if ['have','has','had',
             'been','is','are','was','were',
             'can','will','must','should','may'
    ].include?(verb)
    uri = @@c_origin + '/tenses' +'/eng/' + verb
    puts(uri)
    response = HTTParty.get(uri)
    jsonHash = JSON.parse(response.body)

    case tense
      when "vb" # base form
        return "" if not jsonHash.include?("gerund") and not jsonHash.include?("presentparticiple")
        changeTense = "presentparticiple"
      when "vbd" # present tense not 3rd
        return "" if not jsonHash.include?("past")
        changeTense = "past"
      when "vbz" # present tense 3rd
        return "" if not jsonHash.include?("past")
        changeTense = "past"
      when "vbg" # gerund (동명사)
        return "" if not jsonHash.include?("pastparticiple")
        changeTense = "pastparticiple"
      when "vbd" # past tense
        return "" if not jsonHash.include?("pastparticiple")
        changeTense = "pastparticiple"
      when "vbn" # past participle
        return "" if not jsonHash.include?("gerund") and not jsonHash.include?("presentparticiple")
        changeTense = "presentparticiple"
      else
        return ""
    end
    changeVerb = verbConjugation(verb, changeTense)
    if changeVerb == verb
      return ""
    else
      return changeVerb
    end
  end
	def advToAdj(adv)
		uri = @@c_origin + '/stems' +'/eng/' + adv
    if ['not','many','very','so','thus'].include? adv
      return ""
    end
    puts(uri)
		response = HTTParty.get(uri)
		jsonHash = JSON.parse(response.body)
    result = String.new
		jsonHash.each do |hash|
			if hash["partofspeech"]["partofspeechcategory"] == "adverb"
        if adv != hash["root"]
          result = hash["root"]
        end
      else
        return ""
			end
    end
    return result

	end
	def antAdj(adj)
		uri = @@a_origin + '?rel_ant=' + adj
		response = HTTParty.get(uri)
		jsonHash = JSON.parse(response.body)
    jsonHash.each do |hash|
      antExceptArr = Array.new
      antExceptArr << "un" + adj
      antExceptArr << "im" + adj
      antExceptArr << "not " + adj
      if !antExceptArr.include? hash["word"]
        return hash["word"]
      end
    end
    return ""
  end

end

class ProblemMaker
	def initialize
		@@tgr = EngTagger.new
		@@word_api = WordAPI.new
    @problemList = Array.new
  end
  def getInput
    @plainText
  end
	def input(text)
		@plainText = text
		# add tag to each word.
		tagged = @@tgr.add_tags(text)
		taggedArray = tagged.split

		# convert one dimension info to two dimension. 
		@tagged2DArray = Array.new
		@tagCountList = Hash.new
    lineArray = Array.new

		lineIndex = 0
		wordIndex = 0
		taggedArray.each do |word|
			tagl = word.index('<')
			tagr = word.index('>')
			tag = word[tagl + 1, tagr - tagl - 1]
			nextTagl = word.rindex('<')
			wd = word[tagr + 1, nextTagl - tagr - 1]
			wNode = WordNode.new(tag, wd, lineIndex, wordIndex)
		
			# storing tag to 2D Array
      if @tagged2DArray[lineIndex] == nil
        @tagged2DArray[lineIndex] = Array.new
      end
			@tagged2DArray[lineIndex] << wNode

			wordIndex = wordIndex + 1
      if lineArray[lineIndex] == nil
        lineArray << wd.downcase
      else
        lineArray[lineIndex] = lineArray[lineIndex] + " " + wd.downcase
      end

			if wd.index('.') != nil || wd.index('?') != nil || wd.index('!') != nil
				lineIndex = lineIndex + 1
        wordIndex = 0
			end
    end

    # change outward tag to real meaning tag.
    lineIndex = 0
    wordIndex = 0
    @tagged2DArray.each do |line|
      conjIndex = nil
      conjLength = -1
      ['in other words','for example','in addition', 'in fact', 'on the contray', 'after all', 'as if', 'as soon as'].each do |conjunction|
        conjIndex = lineArray[lineIndex].index(conjunction)
        if conjIndex != nil
          conjLength = conjunction.length
          break
        end
      end

      strIndex = 0
      line.each do |word|
        wd = word.wd
        if strIndex == conjIndex
          @tagged2DArray[lineIndex][wordIndex].tag = 'cc'
          strIndex = strIndex + @tagged2DArray[lineIndex][wordIndex].wd.length
          loop do
            break if @tagged2DArray[lineIndex][wordIndex + 1] == nil
            strIndex = strIndex + @tagged2DArray[lineIndex][wordIndex + 1].wd.length + 1
            @tagged2DArray[lineIndex][wordIndex].wd = @tagged2DArray[lineIndex][wordIndex].wd + " " + @tagged2DArray[lineIndex][wordIndex + 1].wd
            @tagged2DArray[lineIndex].delete_at(wordIndex + 1)
            break if strIndex >= conjIndex + conjLength
          end
          break
        else
          strIndex = strIndex + wd.length
          wordIndex = wordIndex + 1
        end
      end
      lineIndex = lineIndex + 1
    end

    # storing tag num.
    @tagged2DArray.each do |line|
      line.each do |word|
        wd = word.wd.to_s.downcase
        tag = word.tag
        if ['not', 'last', 'first', 'free'] == wd
          wd = wd + 'what the fuck'
          next
        end

        if ["vb", "vbd", "vbz", "vbg", "vbd", "vbn"].include?(tag)
          verbTag = 'verb'
          if @tagCountList[verbTag] == nil
            @tagCountList[verbTag] = Array.new
          end
          @tagCountList[verbTag] << word
        end
        if @tagCountList[tag] == nil
          @tagCountList[tag] = Array.new
        end
        @tagCountList[tag] << word
      end
    end
	end
		# by using each tag Count, suggest the problem making case.
	def caseParsing
    if @plainText == nil
      puts "please first input your english text."
      return
    end
    @caseList = {
        "adv_to_adj" => Array.new,
        "ant_adj" => Array.new,
        "tense_change" => Array.new,
        "relative_pronoun" => Array.new,
        "conjunction" => Array.new
    }

    @tagged2DArray.each do |line|
      line.each do |word|
        next if 'not' == word.wd.to_s

        case word.tag
					when "rb"
						candWord = @@word_api.advToAdj(word.wd.to_s)

						if candWord != ""
							newCand = Candidate.new(candWord.to_s , word.li.to_i , word.wi.to_i)
							@caseList["adv_to_adj"] << newCand
						end
					when "jjr"
						# change to little, more, like that.
          when "jj"
            next if ['last','first','free'].include?(word.wd.to_s.downcase)
						candWord = @@word_api.antAdj(word.wd.to_s)

						if candWord != ""
              puts word.wd.to_s + "to" + candWord
							newCand = Candidate.new(candWord.to_s, word.li.to_i, word.wi.to_i)
							@caseList["ant_adj"] << newCand
						end
          when "vb", "vbd", "vbz", "vbg", "vbd", "vbn"
            candWord = @@word_api.tenseChange(word.wd.to_s, word.tag)
            if candWord != ""
              puts word.wd.to_s + "to" + candWord
              newCand = Candidate.new(candWord.to_s, word.li.to_i, word.wi.to_i)
              @caseList["tense_change"] << newCand
            end
          when "wdt", "wp", "wps", "wrb"
            ##WDT	WH-determiner	          that what which
            ##WP	  WH-pronoun	            who whom
            ##WP$	WH-pronoun, possessive	whose
            ##WRB	Wh-adverb	              how however whenever where
            case word.wd.to_s
              when "that"
                candWord = "what"
              when "what"
                candWord = "that"
              when "where"
                candWord = "which"
              when "whose"
                candWord = "who"
              when "which"
                candWord = "where"
              else next

            end
            puts word.wd.to_s + "to" + candWord
            newCand = Candidate.new(candWord.to_s, word.li.to_i, word.wi.to_i)
            @caseList["relative_pronoun"] << newCand
          when "cc"
            # 'in other words','for example','in addition', 'in fact', 'on the contray', 'after all', 'as if', 'as soon as'
            #CC	conjunction, coordinating	and but or yet
            print "CC!" + word.wd.to_s
            case word.wd.to_s.downcase
              when "and"
                candWord = "or"
              when "but"
                candWord = "that"
              when "or"
                candWord = "which"
              when "whose"
                candWord = "who"
              when "which"
                candWord = "where"
              when "in other words"
                candWord = "just test"
              else next
            end
            puts word.wd.to_s + "to" + candWord
            newCand = Candidate.new(candWord.to_s, word.li.to_i, word.wi.to_i)
            @caseList["conjunction"] << newCand
        end
			end
    end

    @caseList.each do |key, value|
      puts key + " Case has " + value.size.to_s + " candidates."
    end

	end
	
	def makeProblem
    @problemList = {
        "grammar" => Array.new,
        "context" => Array.new,
        "adv_to_adj" => Array.new,
        "ant_adj" => Array.new,
        "tense_change" => Array.new
    }
    ## Grammar error problem with adv_to_adj & tense change & ant_adj
    ## verb and adjective will be candidates.
    ##

    if @tagCountList['jj'].size < 3 or @tagCountList['verb'].size < 3
      print "Can't make graamar prblem. there was not enough candidates."
    else
      @caseList["adv_to_adj"].each do |candidate|
        adjCandNum = 2 + Random.rand(1)
        verbCandNum = 4 - adjCandNum

        problem = String.new
        correctArr = Array.new
        li = candidate.li
        wi = candidate.wi
        candWord = @tagged2DArray[li][wi]
        correctArr << candWord

        adjRandArr = rand_n(adjCandNum, @tagCountList['jj'].size)
        verbRandArr = rand_n(verbCandNum, @tagCountList['verb'].size)
        adjRandArr.each do |randIndex|
          correctArr << @tagCountList['jj'][randIndex]
        end
        verbRandArr.each do |randIndex|
          correctArr << @tagCountList['verb'][randIndex]
        end


        candNum = 1
        correctNum = -1
        @tagged2DArray.each do |line|
          line.each do |word|
            if correctArr.include?(word)
              if word == candWord
                problem = problem + " [" + candNum.to_s + "] " + candidate.cd
                correctArr.delete(word)
                correctNum = candNum
              else
                problem = problem + " [" + candNum.to_s + "] " + word.wd
                correctArr.delete(word)
              end
              candNum = candNum + 1
            else
              problem = problem + ' ' + word.wd
            end
          end
        end
        problem = problem + "\ncorrect Number" + correctNum.to_s + " ,Answer is " + candWord.wd
        @problemList["grammar"] << problem
      end
      @caseList["tense_change"].each do |candidate|
        adjCandNum = 2 + Random.rand(1)
        verbCandNum = 4 - adjCandNum

        problem = String.new
        correctArr = Array.new
        li = candidate.li
        wi = candidate.wi
        candWord = @tagged2DArray[li][wi]
        correctArr << candWord

        adjRandArr = rand_n(adjCandNum, @tagCountList['jj'].size)
        verbRandArr = rand_n(verbCandNum, @tagCountList['verb'].size)
        adjRandArr.each do |randIndex|
          correctArr << @tagCountList['jj'][randIndex]
        end
        verbRandArr.each do |randIndex|
          correctArr << @tagCountList['verb'][randIndex]
        end

        candNum = 1
        correctNum = -1
        @tagged2DArray.each do |line|
          line.each do |word|
            if correctArr.include?(word)
              if word == candWord
                problem = problem + "[" + candNum.to_s + "]" + candidate.cd
                correctArr.delete(word)
                correctNum = candNum
              else
                problem = problem + "[" + candNum.to_s + "]" + word.wd
                correctArr.delete(word)
              end
              candNum = candNum + 1
            else
              problem = problem + ' ' + word.wd
            end
          end
        end
        problem = problem + "\ncorrect Number" + correctNum.to_s + " ,Answer is " + candWord.wd
        @problemList["grammar"] << problem
      end
    end
    # making antAdj Problem. It's size have to larger than 3

    if @caseList["ant_adj"].size >= 3
      # making combinations
      candCombList = @caseList["ant_adj"].combination(3).to_a
      candCombList.each do |candList|
        problem = String.new
        candArr = Array.new
        correctArr = Array.new
        tripleArr = Array.new

        candList.each do |candidate|
          li = candidate.li
          wi = candidate.wi
          correctArr << @tagged2DArray[li][wi]
          candArr << candidate.cd
        end

        correctTriple = Triple.new
        correctTriple.one = correctArr[0].wd
        correctTriple.two = correctArr[1].wd
        correctTriple.three = correctArr[2].wd
        tripleArr << correctTriple

        candNum = 0
        candCharArr =[ 'A', 'B', 'C']
        randOrderArr = Array.new

        @tagged2DArray.each do |line|
          line.each do |word|
            if correctArr.include?(word)
              randOrder = Random.rand(2)
              randOrderArr << randOrder
              if randOrder == 0
                problem = problem + "[" + candCharArr[candNum] + "]" + candArr[candNum] + "/" + correctArr[candNum].wd
              else
                problem = problem + "[" + candCharArr[candNum] + "]" + correctArr[candNum].wd + "/" + candArr[candNum]
              end
              candNum = candNum + 1
            else
              problem = problem + ' ' + word.wd
            end
          end
        end
        # candList 에서 하나 뽑고 correctList 에서 하나 뽑고 Triple로 만들어준다
        #000 010, 011, 110, 101

        while tripleArr.size != 5
          candTriple = Triple.new
          for i in 0..2
            randOrder = Random.rand(2)
            if randOrder == 0
              candTriple.set(i, candArr[i])
            else
              candTriple.set(i, correctArr[i].wd)
            end
          end
          notOverLap = true
          tripleArr.each do |triple|
            if (triple.one == candTriple.one) && (triple.two == candTriple.two) && (triple.three == candTriple.three)
              notOverLap = false
              break
            end
          end
          if notOverLap
            tripleArr << candTriple
          end
        end
        # triple sorting by ascending char order.
        #tripleArr.sort_by {|triple| triple.first}
        tripleArr.sort {|a,b| (a.one == b.one) ? a.two <=> b.two : a.one <=> b.one}


        problem = problem + "\n\t(A) \t (B) \t (C)\n"

        tripleNum = 0
        tripleArr.each do |triple|
          problem = problem + "[" + (tripleNum+1).to_s + "]"
          problem = problem + triple.one + "\t" + triple.two + "\t" + triple.three + "\n"
          tripleNum = tripleNum + 1
        end
        @problemList["ant_adj"] << problem
      end


    end
  end
  def printProblem(param)
    if @problemList[param].size == 0
      puts "there are no such " + param + "problem. sorry."
    end
    @problemList[param].each do |problem|
      puts problem
    end

  end
end
# Sample text
testText = %q[Mathematics will attract those it can attract, but it will do nothing to overcome the resistance to science. Science is universal in principle but in practice it speaks to very few. Mathematics may be considered a communication skill of the highest type, frictionless so to speak; and at the opposite pole from mathematics, the fruits of science show the practical benefits of science without the use of words. But as we have seen, those fruits are ambivalent. Science as science does not speak; ideally, all scientific concepts are mathematized when scientists communicate with on e another, and when science displays its products to non-scientists it need not, and indeed is not able to, resort to salesmanship. When science speaks to others it is no longer science, and the scientist becomes or has to hire a publicist who dilutes the exactness of mathematics. In doing so the scientist reverses his drive toward mathematical exactness in favor of rhetorical vagueness and metaphor, thus violating the code of intellectual conduct that defines him as a scientist.]
testText = %q[I hope you remember our discussion last Monday about the servicing of the washing machine supplied to us three months ago. I regret to say the machine is no longer working. As we agreed during the meeting, please send a service engineer as soon as possible to repair it. The product warranty says that you provide spare parts and materials for free, but charge for the engineer’s labor. This sounds unfair. I believe the machine’s failure is caused by a manufacturing defect. Initially, it made a lot of noise, and later, it stopped operating entirely. As it is wholly the company’s responsibility to correct the defect, I hope you will not make us pay for the labor component of its repair.]
#testText = "In other words, there are so many things."
pbr = ProblemMaker.new
pbr.input(testText)
pbr.caseParsing
pbr.makeProblem
pbr.printProblem('grammar')

=begin
pbr = ProblemMaker.new
begin
  puts "What do you want to do? Choose your method"
  puts "1. input 2. caseParsing 3.makeProblem 4. printProblem X.Exit"
  input = gets.chomp
  case input
    when "1"
      puts "Please input your English text"
      testText = gets.chomp
      pbr.input(testText)
    when "2"
      pbr.caseParsing
    when "3"
      pbr.makeProblem
    when "4"
      puts "What do you want to category? 1)adv_to_adj 2) ant_adj"
      select = gets.chomp.to_i
      case select
        when 1
          category = "adv_to_adj"
        when 2
          category = "ant_adj"
      end
      pbr.printProblem(category)
    else
  end
end while input != "X"
puts "bye bye "
=end
tgr = EngTagger.new
# Add part-of-speech tags to text
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
