# -*- coding: utf-8 -*-
require "open-uri"
require "json"

class RakutenWebService

  Error = Class.new StandardError
  NotFound = Class.new Error
  ServerError = Class.new Error
  ClientError = Class.new Error
  Maintenance = Class.new Error
  UnknownError = Class.new Error

  DEVELOPER_ID = 'c4864d89bcbec6568073b69dc9554776'
  AFFILIATE_ID = '0439dab5.9ef66f07.0439dab6.7f73d9fa'

  def initialize(opt={})
    @cache_dir = opt[:cache_dir]
    @affiliate_id = opt[:affiliate_id] || AFFILIATE_ID
    Dir.mkdir @cache_dir if @cache_dir and not File.directory? @cache_dir
  end

  # ISBN コードに対応する情報を返す
  def isbn(isbn)
    begin
      book(isbn)
    rescue NotFound
      foreign_book(isbn)
    end
  end

  # JAN コードに対応する情報を返す
  def jan(jan)
    methods = [:cd, :dvd, :magazine, :game, :software]
    begin
      method(methods.shift).call(jan)
    rescue NotFound
      raise if methods.empty?
      retry
    end
  end

  # 楽天商品コードに対応する情報を返す
  def item(code)
    cache = @cache_dir && "#{@cache_dir}/item_#{code}.json"
    uri = "http://api.rakuten.co.jp/rws/2.0/json?developerId=#{DEVELOPER_ID}&affiliateId=#{@affiliate_id}&operation=ItemCodeSearch&version=2007-04-11&itemCode=#{code}"
    ret = get_item uri, cache
    ret["Body"]["ItemCodeSearch"]["Items"]["Item"].first
  end

  # isbn に対応する書籍情報を返す
  def book(isbn)
    get_books_item 'BooksBookSearch', 'isbn', isbn
  end

  # isbn に対応する洋書情報を返す
  def foreign_book(isbn)
    get_books_item 'BooksForeignBookSearch', 'isbn', isbn
  end

  # jan に対応するCD情報を返す
  def cd(jan)
    get_books_item 'BooksCDSearch', 'jan', jan
  end

  # jan に対応するDVD情報を返す
  def dvd(jan)
    get_books_item 'BooksDVDSearch', 'jan', jan
  end

  # jan に対応する雑誌情報を返す
  def magazine(jan)
    get_books_item 'BooksMagazineSearch', 'jan', jan
  end

  # jan に対応するゲーム情報を返す
  def game(jan)
    get_books_item 'BooksGameSearch', 'jan', jan
  end

  # jan に対応するソフト情報を返す
  def software(jan)
    get_books_item 'BooksSoftwareSearch', 'jan', jan
  end

  # hotel_id に対応するホテル情報を返す
  def hotel(hotel_id)
    cache = @cache_dir && "#{@cache_dir}/travel_#{hotel_id}.json"
    uri = "http://api.rakuten.co.jp/rws/3.0/json?developerId=#{DEVELOPER_ID}&affiliateId=#{@affiliate_id}&operation=HotelDetailSearch&version=2009-09-09&hotelNo=#{hotel_id}"
    ret = get_item uri, cache
    ret["Body"]["HotelDetailSearch"]["hotel"].first
  end

  private

  # 楽天Booksからアイテムを取得
  def get_books_item(ope, type, id)
    cache = @cache_dir && "#{@cache_dir}/#{type}_#{id}.json"
    uri = "http://api.rakuten.co.jp/rws/2.0/json?developerId=#{DEVELOPER_ID}&affiliateId=#{@affiliate_id}&outOfStockFlag=1&operation=#{ope}&version=2009-04-15&#{type}=#{id}"
    ret = get_item uri, cache
    ret["Body"][ope]["Items"]["Item"].first
  end

  # uri の返した文字列を JSON としてパースした値を返す。
  # cache_path ファイルがあれば uri にアクセスする代わりにそれを使用する。
  def get_item(uri, cache_path=nil)
    if cache_path
      begin
        return JSON.parse(File.read cache_path)
      rescue Errno::ENOENT
        # ignore
      end
    end
    json = OpenURI.open_uri(uri){|io| io.read}
    ret = JSON.parse json
    status = ret["Header"]["Status"]
    if status == 'Success'
      File.open(cache_path, 'w'){|f| f.write json} if cache_path
      return ret
    end
    if ['NotFound', 'ServerError', 'ClientError', 'Maintenance'].include? status
      raise self.class.const_get(status), ret['Header']['StatusMsg']
    end
    raise UnknownError
  end
end
