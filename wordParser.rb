require 'httparty'
require 'nokogiri'
require 'open-uri'
# get request enum value.
$target = {
	mid_1: 1100001,
	mid_2: 1100002,
	mid_3: 1100003,
	high_c: 110004,
	high_1: 110005,
	high_2:	110006,
	# publisher
}
$publisher = {
	mid_1: 	210001,
	mid_2: 	220001,
	mid_3: 	230001,
	high_c: 240001,
	high_1: 250001,
	high_2:	260001,
	
}
	
doc = Nokgoiri::HTML(open("http://endic.naver.com/lesson.nhn?sLn=kr&fristId=110001&secondId=&thirdId=&fourId=&pageNo=1&pubLev=all&firstWord=all&posp=all"))
response = HTTParty.get('http://endic.naver.com/lesson.nhn?sLn=kr&fristId=110001&secondId=&thirdId=&fourId=&pageNo=1&pubLev=all&firstWord=all&posp=all')


puts response.body
# Or wrap things up in your own class
class WordParser
  base_uri 'endic.naver.com'

  def initialize(, )
    @options = { query: 
								{ 
											sLn: "kr",
																					
										 	site: service,
										 	page: page 
								}
							 }
  end
	def lessons
		html = HTTParty.get("/lesson.nhn", @options)
		html_doc = Nokogiri::HTML(html)
		trList = html_doc.css('div.entrylist').css('table').css('tbody').css('tr')
		trList.each{ |tr|
			
		}
.each{|tr|  tr.css('td').css('div').css('a').css('span').text}
	end
end

stack_exchange = StackExchange.new("stackoverflow", 1)
puts stack_exchange.questions
puts stack_exchange.users
