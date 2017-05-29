#!/usr/bin/env ruby
require 'rubygems'
require 'engtagger'
require 'nokogiri'
require 'httparty'
require 'json'
require 'set'

# for having two selections.
class Double
  attr_accessor :one, :two, :three
  def set(param, data)
    case param
      when 0
        @one = data
      when 1
        @two = data
    end
  end
end

# for having three selections.
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
def rand_n(tagCountList, n, max)
  randoms = Set.new
  loop do
    randNum = rand(max)
    insert = true
    randoms.each do |num|
      if tagCountList[num].li == tagCountList[randNum].li
        insert = false
        break
      end
    end
    if insert
      randoms << randNum
      return randoms.to_a if randoms.size >= n
    end
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
    puts(uri)
		response = HTTParty.get(uri)
		jsonHash = JSON.parse(response.body).reverse
    jsonHash.each do |hash|
      antExceptArr = ["un" + adj, "im" + adj, "dis" + adj, "not " + adj, "ab" + adj, "in" + adj, "non" + adj]
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
      if ["however","similarly", "additionally"].include?(wd.downcase)
        tag = "cc"
      end
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
			if wd.index('.') != nil or wd.index('?') != nil or wd.index('!') != nil
				lineIndex = lineIndex + 1
        wordIndex = 0
			end
    end

    # change outward tag to real meaning tag.
    lineIndex = 0
    wordIndex = 0
    @tagged2DArray.each do |line|
      phraseIndex = nil
      phraseLength = -1
      phrasePart = nil

      ['in other words',
       'for example', 'such as', 'for instance',
       'in contrast', 'on the contray', 'on the other hand', 'by contrast',
       'in addition', 'what is more',
       'in fact',
       'after all', 'as a result', 'as a consequence', 'in brief', 'in short', 'in conclusion',
       'as if', 'as soon as'].each do |conjunction|

        phraseIndex = lineArray[lineIndex].downcase.index(conjunction)
        if phraseIndex != nil
          print ("YEAH " + conjunction + "\n")
          phraseLength = conjunction.length
          phrasePart = "cc"
          print phrasePart + "\n"
          print phraseIndex.to_s + "\n"
          break
        end
      end
      if phraseIndex == nil
        ['in which','on which', 'in which', 'by which', 'of whom', 'for whom'].each do |wrb|
          phraseIndex = lineArray[lineIndex].downcase.index(wrb)
          if phraseIndex != nil
            phraseLength = wrb.length
            phrasePart = "wrb"
            break
          end
        end
      end
      if phraseIndex != nil
        strIndex = 0
        line.each do |word|

          wd = word.wd

          if strIndex == phraseIndex
            @tagged2DArray[lineIndex][wordIndex].tag = phrasePart
            strIndex = strIndex + @tagged2DArray[lineIndex][wordIndex].wd.length
            loop do
              break if @tagged2DArray[lineIndex][wordIndex + 1] == nil
              strIndex = strIndex + @tagged2DArray[lineIndex][wordIndex + 1].wd.length + 1
              @tagged2DArray[lineIndex][wordIndex].wd = @tagged2DArray[lineIndex][wordIndex].wd + " " + @tagged2DArray[lineIndex][wordIndex + 1].wd
              @tagged2DArray[lineIndex].delete_at(wordIndex + 1)
              break if strIndex >= phraseIndex + phraseLength
            end
          else
            strIndex = strIndex + wd.length + 1
            wordIndex = wordIndex + 1
          end
        end
      end
      lineIndex = lineIndex + 1
      wordIndex = 0
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
        "tense_change" => Array.new,
        "relative_pronoun" => Array.new,

        "ant_adj" => Array.new,
        "conjunction" => Array.new
    }

    @tagged2DArray.each do |line|
      line.each do |word|
        next if 'not' == word.wd.to_s

        case word.tag
          when "rb"
            next
						candWord = @@word_api.advToAdj(word.wd.to_s)
						if candWord != ""
              if word.wd.to_s[0] == word.wd.to_s[0].upcase
                candWord[0] = candWord[0].upcase
              end
							newCand = Candidate.new(candWord.to_s , word.li.to_i , word.wi.to_i)
							@caseList["adv_to_adj"] << newCand
						end
          when "jjr"

						# change to little, more, like that.
          when "jj"

            next if ['last','first', 'free'].include?(word.wd.to_s.downcase)
						candWord = @@word_api.antAdj(word.wd.to_s)

						if candWord != ""
              if word.wd.to_s[0] == word.wd.to_s[0].upcase
                candWord[0] = candWord[0].upcase
              end
              puts word.wd.to_s + "to" + candWord
							newCand = Candidate.new(candWord.to_s, word.li.to_i, word.wi.to_i)
							@caseList["ant_adj"] << newCand
						end
          when "vb", "vbd", "vbz", "vbg", "vbd", "vbn"
            next
            candWord = @@word_api.tenseChange(word.wd.to_s, word.tag)
            if candWord != ""
              if word.wd.to_s[0] == word.wd.to_s[0].upcase
                candWord[0] = candWord[0].upcase
              end
              puts word.wd.to_s + "to" + candWord
              newCand = Candidate.new(candWord.to_s, word.li.to_i, word.wi.to_i)
              @caseList["tense_change"] << newCand
            end
          when "wdt", "wp", "wps", "wrb"
            ##WDT	WH-determiner	          that what which
            ##WP	  WH-pronoun	            who whom
            ##WP$	WH-pronoun, possessive	whose
            ##WRB	Wh-adverb	              how however whenever where
            candArr = ['what', 'which', 'when', 'that', 'what', 'where', 'whose']
            candArr.delete(word.wd)
            randNum = Random.rand(5)
            case word.wd.downcase
              when "that", "what", "where", "whose", "which"
                candWord = candArr[randNum]
              when "in which","on which", "in which", "by which", "of whom", "for whom"
                candWord = word.wd.split(' ')[1]
              else next
            end
            if word.wd.to_s[0] == word.wd.to_s[0].upcase
              candWord[0] = candWord[0].upcase
            end
            puts word.wd.to_s + "to" + candWord
            newCand = Candidate.new(candWord.to_s, word.li.to_i, word.wi.to_i)
            @caseList["relative_pronoun"] << newCand
          when "cc"
            # 'in other words','for example','in addition', 'in fact', 'on the contray', 'after all', 'as if', 'as soon as'
            #CC	conjunction, coordinating	and but or yet
            next if ['and', 'or', 'so', 'but'].include?(word.wd.to_s.downcase)
            print "CC!" + word.wd.to_s + "\n"
            candWordList = [
                "in other words", "in fact",
                "for example", "such as", "for instance",
                "in contrast", "on the contray", "on the other hand", "by contrast", "however",
                "in addition", "what is more", "similarly", "additionally",
                "after all", "as a result", "as a consequence", "in brief", "in short", "in conclusion", "as a result",
                "neverthless", "although"]
            case word.wd.to_s.downcase
              when "in other words", "in fact"
                ccList = ["in other words", "in fact"]
              when "for example", "such as", "for instance"
                ccList = ["for example", "such as", "for instance"]
              when "in contrast", "on the contray", "on the other hand", "by contrast", "however"
                ccList = ["in contrast", "on the contray", "on the other hand", "by contrast", "however"]
              when "in addition", "what is more", "similarly", "additionally"
                ccList = ["in addition", "what is more", "similarly", "additionally"]
              when "after all", "as a result", "as a consequence", "in brief", "in short", "in conclusion", "as a result"
                ccList = ["after all", "as a result", "as a consequence", "in brief", "in short", "in conclusion", "as a result"]
              when "neverthless", "although"
                ccList = ["after all", "as a result", "as a consequence", "in brief", "in short", "in conclusion", "as a result"]
              else next
            end
            ccList.each do |x|
              candWordList.delete(x)
            end
            candWordArr = candWordList.sample(2)
            if word.wd.to_s[0].upcase == word.wd.to_s[0]
              candWordArr.each do |candWord|
                candWord[0] = candWord[0].upcase
              end
            end
            candWord = candWordArr.join(",")
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
        "context" => Array.new
    }
    ## Grammar error problem with adv_to_adj & tense change & ant_adj
    ## verb and adjective will be candidates.
    ##

    if @tagCountList['jj'].size < 3 or @tagCountList['verb'].size < 3
      print "Can't make graamar prblem. there was not enough candidates."
    else
      @caseList["adv_to_adj"].each do |candidate|
        adjCandNum = 1 + Random.rand(1)
        verbCandNum = 4 - adjCandNum

        problem = String.new
        correctArr = Array.new
        li = candidate.li
        wi = candidate.wi
        candWord = @tagged2DArray[li][wi]
        correctArr << candWord

        adjRandArr = rand_n(@tagCountList['jj'],adjCandNum, @tagCountList['jj'].size)
        verbRandArr = rand_n(@tagCountList['verb'], verbCandNum, @tagCountList['verb'].size)
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

        adjRandArr = rand_n(@tagCountList['jj'],adjCandNum, @tagCountList['jj'].size)
        verbRandArr = rand_n(@tagCountList['verb'], verbCandNum, @tagCountList['verb'].size)
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
      @caseList["relative_pronoun"].each do |candidate|
        adjCandNum = 2 + Random.rand(1)
        verbCandNum = 4 - adjCandNum

        problem = String.new
        correctArr = Array.new
        li = candidate.li
        wi = candidate.wi
        candWord = @tagged2DArray[li][wi]
        correctArr << candWord

        adjRandArr = rand_n(@tagCountList['jj'], adjCandNum, @tagCountList['jj'].size)
        verbRandArr = rand_n(@tagCountList['verb'], verbCandNum, @tagCountList['verb'].size)
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
      @caseList["ant_adj"].each do |candidate|
        adjCandNum = 2 + Random.rand(1)
        verbCandNum = 4 - adjCandNum

        problem = String.new
        correctArr = Array.new
        li = candidate.li
        wi = candidate.wi
        candWord = @tagged2DArray[li][wi]
        correctArr << candWord

        adjRandArr = rand_n(@tagCountList['jj'], adjCandNum, @tagCountList['jj'].size)
        verbRandArr = rand_n(@tagCountList['verb'], verbCandNum, @tagCountList['verb'].size)
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
        @problemList["context"] << problem
      end
    end


    ## CONTEXT PROBLEM
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
        tripleArr = tripleArr.sort do |a,b|
          comp = (a.one <=> b.one)
          comp.zero? ? (a.two <=> b.two) : comp
          comp.zero? ? (a.three <=> b.three) : comp
        end


        problem = problem + "\n\t(A) \t (B) \t (C)\n"

        tripleNum = 0
        correctNum = -1
        tripleArr.each_with_index do |triple, index|
          correctNum = index + 1 if correctTriple.one == triple.one and correctTriple.two == triple.two and correctTriple.three == triple.three
          problem = problem + "[" + (tripleNum+1).to_s + "]"
          problem = problem + triple.one + "\t" + triple.two + "\t" + triple.three + "\n"
          tripleNum = tripleNum + 1
        end

        problem = problem + "\ncorrect Number" + correctNum.to_s + " ,Answer is " + correctTriple.one + ", " + correctTriple.two + ", " + correctTriple.three
        @problemList["context"] << problem
      end


    end
    if @caseList["conjunction"].size >= 2
      # making combinations
      candCombList = @caseList["conjunction"].combination(2).to_a
      candCombList.each do |candList|
        problem = String.new
        candArr = Array.new
        correctArr = Array.new
        doubleArr = Array.new

        candList.each do |candidate|
          li = candidate.li
          wi = candidate.wi
          correctArr << @tagged2DArray[li][wi]
          candArr << candidate.cd
        end
        correctDouble = Double.new

        correctDouble.one = correctArr[0].wd
        correctDouble.two = correctArr[1].wd
        doubleArr << correctDouble

        candNum = 0
        candCharArr =[ 'A', 'B']

        @tagged2DArray.each do |line|
          line.each do |word|
            if correctArr.include?(word)
              problem = problem + " [" + candCharArr[candNum] + "] "
              candNum = candNum + 1
            else
              problem = problem + ' ' + word.wd
            end
          end
        end
        # candList 에서 하나 뽑고 correctList 에서 하나 뽑고 Triple로 만들어준다
        #000 010, 011, 110, 101

        while doubleArr.size != 5
          candDouble = Double.new
          for i in 0..1
            randOrder = Random.rand(3)
            splitedCandArr = candArr[i].split(',')

            if randOrder == 0
              candDouble.set(i, splitedCandArr[0])
            elsif randOrder == 1
              candDouble.set(i, splitedCandArr[1])
            else
              candDouble.set(i, correctArr[i].wd)
            end
          end
          notOverLap = true
          doubleArr.each do |double|
            if (double.one == candDouble.one) && (double.two == candDouble.two)
              notOverLap = false
              break
            end
          end
          if notOverLap
            doubleArr << candDouble
          end
        end

        # double sorting by ascending char order.
        #doubleArr.sort_by {|triple| triple.first}
        doubleArr = doubleArr.sort do |a,b|
          comp = (a.one <=> b.one)
          comp.zero? ? (a.two <=> b.two) : comp
        end

        problem = problem + "\n\t(A) \t (B) \n"

        doubleNum = 0
        correctNum = -1
        doubleArr.each_with_index do |double,index|
          if correctDouble.one == double.one and correctDouble.two == double.two
            correctNum = index + 1
          end

          problem = problem + "[" + (doubleNum+1).to_s + "] "
          problem = problem + double.one + "\t" + double.two + "\n"
          doubleNum = doubleNum + 1
        end
        problem = problem + "\ncorrect Number" + correctNum.to_s + " ,Answer is " + correctDouble.one + ", " + correctDouble.two
        @problemList["context"] << problem
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
testText = %q[F. Scott Fitzgerald thought that the test of first-rate
intelligence was the ability to hold two opposed ideas in mind at the same time and still function. The eons shaped our brains in the opposite direction. Confirmation bias is a term for the way the mind systematically avoids confronting contradiction. It does this by overvaluing evidence that confirms what we already think or feel and undervaluing or simply disregarding evidence that refutes it. Testimony from members of the Crow tribe about the destruction of their culture provides an extreme and tragic example of this. A man named Plenty Coups reported that “when the buffalo went away, the hearts of my people fell to the ground and they could not lift them up again. After this nothing happened.” He was not alone in describing the depth of despair as the end of history. “Nothing happened after that,” another Crow warrior said. “We just lived.” The emotion was so strong that the brain rejected evidence of the continued existence of normal, everyday life that might have eased it.]
testText = %q[New media can be defined by four characteristics simultaneously. they are media at the turn of the 20th and 21st centuries which are both integrated and interactive and use digital code and hypertext as technical means. It follows that their most common alternative names are multimedia, interactive media and digital media. By using this definition, it is easy to identify media as old or new. For example , traditional television is integrated as it contains images, sound and text, but it is not interactive or based on digital code. The plain old telephone was interactive, but not integrated as it only transmitted speech and sounds and it did not work with digital code. In contrast, the new medium of interactive television adds interactivity and digital code. Additionally , the new generations of mobile or fixed telephony are fully digitalized and integrated as they add text, pictures or video and they are connected to the Internet.]
testText = %q[Persuasion is the strategic use of language to move an audience. It works by appealing to our emotion as well as by appealing to our reason. Therefore, sometimes you may try to appeal to an emotion in your audience by imitating it. hysteria by being hysterical, anger by raging. Also , you may try to re-create the circumstances which excited in you the emotions that you want to excite in your audience. However, the best measure is to appear calm, detached, thoroughly in control of your feelings, while you are controlling your narrative for your own purposes. Even your choice of words should be selective; you must pay attention to their nuances. If you address a labor union,for example, it will make a great difference whether you refer to the members as workers, comrades, or just people.]
testText = %q[Girls usually agreed that wearing a uniform to school every day reduced their daily stresses. Not having to worry about what to wear meant one less decision to make every morning. Many of them also felt that the uniform enhanced school spirit and solidarity. They could feel like they belong to a community. Moreover, the uniforms maintained their individuality. If you want to know a thousand and one ways to modify a school uniform, just ask the girls who wear it: ties can be worn loosely or tight, and skirts can be raised or lowered in any of a half-dozen ways. Then there are accessories―a gray region in the dress code, but an entire subcontinent in the world of women’s apparel. There are a million options in the domain of hairpins, watches, and bags alone.]
testText = %q[Organic food production is growing by leaps and bounds. Many consumers are willing to pay premium prices for organic foods, convinced that they are helping the earth and eating healthier. Some experts say, however, that organic farming has some drawbacks. One of the most frequent criticisms is that the crop yields of organic farms are much lower than those of traditional farms. That’s because organic fields suffer more from weeds and insects than conventional fields. Another argument often offered by experts is that organic farming can supply food for niche markets of wealthy consumers but cannot feed billions of hungry people around the globe. Only the careful use of chemical inputs, not the costly organic methods, can help boost food production significantly in the countries facing hunger.]
#testText = "In other words, there are so many things."
pbr = ProblemMaker.new
pbr.input(testText)
pbr.caseParsing
pbr.makeProblem
pbr.printProblem('context')


my_hash = {:hello => "goodbye"}
JSON.generate(my_hash) # "{\"hello\":\"goodbye\"}"

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
