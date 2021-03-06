require "uri"

class Bookmark < ActiveRecord::Base

  # gem acts_as_indexed: http://douglasfshearer.com/blog/rails-plugin-acts_as_indexed
  acts_as_indexed :fields => [:url, :tag_names]

  has_many :taggings, :dependent => :destroy
  has_many :tags, :through => :taggings

  # Thanks to: http://railscasts.com/episodes/167-more-on-virtual-attributes
  attr_writer :tag_names
  after_save :assign_tags
  after_update :assign_tags

  validates_presence_of :url
  validates_uniqueness_of :url
  validates_format_of :url, :with => URI.regexp

  # gem will_paginate
  cattr_reader :per_page, :per_page_min, :per_page_max
  @@per_page = 5
  @@per_page_min = 1
  @@per_page_max = 100


  def tag_names
    @tag_names || tags.collect(&:name).join(', ')
  end

  # Also see:
  # Xapian (like Lucene): http://blog.evanweaver.com/articles/2008/05/26/xapian-search-plugin/
  #                       http://squeejee.com/blog/2008/07/23/simple-ruby-on-rails-full-text-search-using-xapian/
  # Thinking Sphinx: http://railscasts.com/episodes/120-thinking-sphinx (requires rake indexing)
  def self.search(search, page, order_by, order_direction, per_page)
    if search.blank? # If its empty, we can use a simple find
      paginate :per_page => per_page, :page => page,
        :include => [:taggings, :tags],
        :order => order_by + ' ' + order_direction
    else
      if order_by
        with_query(search).paginate(:page => page, :per_page => per_page,
                                    :order => order_by + ' ' + order_direction)
      else # order by default acts_as_indexed relevance
        with_query(search).paginate(:page => page, :per_page => per_page)
      end
    end
  end


  private

    def assign_tags
      # TODO:
      # http://railsforum.com/viewtopic.php?pid=32557#p32557
      # tags = 'foo bar "foo bar" foobar barfoo'
      # tags.scan(/(\w+)|"(.+?)"/).flatten.compact
      # TODO: clear up this evil Regexp mess
      if @tag_names = @tag_names.gsub(/^[\s|,]*/, '').gsub(/[\s|,]*$/, '').gsub(/(\s,|,\s)+/  , ',')
      # Remove whitespace+comma.. . ^ before ...         ^ after ...          ^ inbetween.
        self.tags = @tag_names.split(/,+/).collect do |name|
          # TODO: remove duplicates
          # TODO: clear up this evil Regexp mess
          name = name.gsub(/\s+/, ' ').strip # Remove white spaces
          unless tag = Tag.find_by_name(name.strip)
            if tag = Tag.create(:name => name.strip)
              self.touch # Bookmark.updated_at
            end
          end
          tag # Return tag to block collect context
        end
      end
    end

end

###
### Failed search implementation 1
###
#
# search = search.gsub(/"/, '\"').gsub(/\?/, '') # NO SQL Injects
# in_search = 'IN ("' + search.gsub(/(\s)+/, '", "') + '")'
# or_search = '= ("' + search.gsub(/(\s)+/, '" OR "') + '")'
# like_or_search = 'LIKE "%' + search.gsub(/(\s)+/, '%" OR "%') + '%"'
# like_xor_search = 'LIKE "%' + search.gsub(/(\s)+/, '%" XOR "%') + '%"'
# like_and_search = 'LIKE "%' + search.gsub(/(\s)+/, '%" AND "%') + '%"'
# bookmarks_search = '(bookmarks.url LIKE "%' +
#   search.gsub(/(\s)+/, '%" OR bookmarks.url LIKE "%') + '%")'
# tags_join_search = '(tags_join.name LIKE "%' +
#   search.gsub(/(\s)+/, '%" OR tags_join.name LIKE "%') + '%")'
# paginate_by_sql ['
#     SELECT bookmarks.id, bookmarks.url, bookmarks.updated_at, tags.name
#     FROM bookmarks
#     LEFT OUTER JOIN taggings ON taggings.bookmark_id = bookmarks.id
#     LEFT OUTER JOIN tags ON tags.id = taggings.tag_id
#     LEFT OUTER JOIN taggings AS taggings_join ON bookmarks.id = taggings_join.bookmark_id
#     LEFT OUTER JOIN tags AS tags_join ON taggings_join.tag_id = tags_join.id
#     WHERE (
#         ' + bookmarks_search + '
#         AND bookmarks.id = taggings.bookmark_id
#         AND taggings.tag_id = tags.id
#         AND tags.id = tags_join.id
#     ) OR (
#       tags_join.name ' + or_search + '
#       AND tags_join.id = taggings_join.tag_id
#       AND taggings_join.bookmark_id = bookmarks.id
#       AND bookmarks.id = taggings.bookmark_id
#       AND taggings.tag_id = tags.id
#     )
#     GROUP BY bookmarks.id
#     ORDER BY ?' + order_direction,
#   "#{order_by}"], :page => page, :per_page => per_page
#   # "#{search}%", "%#{search}%", "%#{search}%"], :page => page, :per_page => per_page
#
###
### Failed search implementation 2
###
#
# http://www.databasejournal.com/sqletc/article.php/1578331/Using-Fulltext-Indexes-in-MySQL---Part-1.htm
# Do not forget: ALTER TABLE bookmarks ADD FULLTEXT (url); ALTER TABLE tags ADD FULLTEXT (name);
# Alternative: http://github.com/dougal/acts_as_indexed
#
# sql_search = search.gsub(/"/, '\"').gsub(/\?/, '') # NO SQL Injects
# or_search = '= ("' + sql_search.gsub(/(\s)+/, '" OR "') + '")'
# like_and_search_urls = 'LIKE "%' + sql_search.gsub(/(\s)+/, '%" AND bookmarks.url LIKE "%') + '%"'
# like_or_search_tags = 'LIKE "%' + sql_search.gsub(/(\s)+/, '%" OR tags.name LIKE "%') + '%"'
#
# paginate_by_sql ['
#     SELECT bookmarks.id, bookmarks.url, bookmarks.updated_at, tags.name,
#       MATCH (bookmarks.url, tags.name) AGAINST (? IN BOOLEAN MODE) AS relevance
#     FROM bookmarks
#       LEFT OUTER JOIN taggings ON taggings.bookmark_id = bookmarks.id
#       LEFT OUTER JOIN tags ON tags.id = taggings.tag_id
#     WHERE
#       (bookmarks.url ' + like_and_search_urls + ')
#       OR
#       (tags.name ' + like_or_search_tags + ')
#     GROUP BY bookmarks.id
#     ORDER BY ' + order_by + ' ' +  order_direction, "#{search}"],
#   :page => page, :per_page => per_page
