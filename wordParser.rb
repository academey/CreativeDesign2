require 'rubygems'
require 'sqlite3'
require 'httparty'
require 'nokogiri'
require 'open-uri'
# get request enum value.
targets = {
	mid_1:  110001,
	mid_2:  110002,
	mid_3:  110003,
	high_c: 110004,
	high_1: 110005,
	high_2:	110006,
	# publisher
}
publishers = {
	mid_1: 	210001,
	mid_2: 	220001,
	mid_3: 	230001,
	high_c: 240001,
	high_1: 250001,
	high_2:	260001,
	
}

#response = HTTParty.get('http://endic.naver.com/lesson.nhn?sLn=kr&fristId=110001&secondId=&thirdId=&fourId=&pageNo=1&pubLev=all&firstWord=all&posp=all')
#puts response.body


# Or wrap things up in your own class
class WordParser
  include HTTParty
  base_uri 'endic.naver.com'
  def initialize
    @options =
        { query:
              {
                  sLn: "kr",
                  site: "lesson.nhn",
                  pubLev: "all",
                  posp: "all"
              }
        }
  end
  public
	def getWordList(firstId, secondId, page)
    @options[:query][:firstId] = firstId
    @options[:query][:secondId] = secondId
    # @options['query']['thirdId'] = thirdId
    @options[:query][:page] = page

		html = self.class.get("/lesson.nhn", @options)

		html_doc = Nokogiri::HTML(html)
		trList = html_doc.css('div.entrylist').css('table').css('tbody').css('tr')
		trList.each do |tr|

			w_name      = tr.css('.f_name').css('div').css('a').css('span').text
      w_mean      = tr.css('.f_name').css('div').css('a').css('span').text.gsub(/\s+/, "")
      w_pos       = tr.css('.f_ps').text
      w_priority  = tr.css('.f_high').css('img')[0]['title']
      w_target    = firstId
      if w_pos == "&nbsp"
        w_pos = "idiom"
      end
      case w_priority
        when "매우 중요"
          w_priority = 2
        when "중요"
          w_priority = 1
        else
          w_priority = 0
      end

      new_word = Word.create(
          name: w_name,
          meaning: w_mean,
          pos: w_pos,
          target: w_target.to_i,
          priority: w_priority.to_i
      )
      if new_word.valid?
        new_word.save
      end

      # s.match(/\s/) == 공백 체크
    end
  end
  def testtt
    print "test"
  end
end
wp = WordParser.new

targets.each do |t_key, t_val|
  for i in 0..15
    for j in 1..15

      wp.getWordList(targets[t_key], (publishers[t_key]+ i), j )
    end
  end
end

