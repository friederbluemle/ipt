require 'pt/switch_ssl'
require 'uri'
require 'tracker_api'

module PT
  class Client < SimpleDelegator

    STORY_FIELDS=':default,requested_by(initials),owners(initials),tasks(complete,description),comments(text,file_attachment_ids,person(initials))'

    attr_reader :config, :client, :total_record, :limit

    def initialize
      @client = TrackerApi::Client.new(token: Settings[:pivotal_api_key])
      self.__setobj__(@client)
      @limit = Settings[:limit] || 10
    end

    def total_page
      @total_record = @client.last_response.env.response_headers["X-Tracker-Pagination-Total"]
      (@total_record.to_f/limit).ceil
    end

    def current_page
       offset = @client.last_response.env.response_headers["X-Tracker-Pagination-Offset"]
       ((offset.to_f/limit)+1).to_i
    end

    def project
      @client.project(Settings[:project_id])
    end

    def get_activities
      project.activity
    end

    def get_work
      project.stories(filter: 'state:unscheduled,unstarted,started', fields: STORY_FIELDS )
    end

    def get_my_work
      project.stories(filter: "owner:#{Settings[:user_name]} -state:accepted", limit: 50, fields: STORY_FIELDS)
    end

    def search_for_story(query, params={})
      params[:filter] =  "#{query}"
      get_stories(params)
    end

    def get_task_by_id(id)
      project.story(id, fields: STORY_FIELDS)
    end
    alias :get_story :get_task_by_id

    def get_my_open_tasks(params={})
      params[:filter] =  "owner:#{Settings[:user_name]}"
      get_stories(params)
    end

    def get_stories_to_estimate(params={})
      params[:filter] =  "owner:#{Settings[:user_name]} type:feature estimate:-1"
      get_stories(params)
    end

    def get_stories_to_start(params={})
      params[:filter] =  "owner:#{Settings[:user_name]} type:feature,bug state:unscheduled,rejected,unstarted"
      tasks = get_stories(params)
      tasks.reject{ |t| (t.story_type == 'feature') && (!t.estimate) }
    end

    def get_stories_to_finish(params={})
      params[:filter] =  "owner:#{Settings[:user_name]} -state:unscheduled,rejected"
      get_stories(params)
    end

    def get_stories_to_deliver(params={})
      params[:filter] =  "owner:#{Settings[:user_name]} -state:delivered,accepted,rejected"
      get_stories(params)
    end

    def get_stories_to_accept(params={})
      params[:filter] =  "owner:#{Settings[:user_name]} -state:accepted"
      get_stories(params)
    end

    def get_stories_to_reject(params={})
      params[:filter] =  "owner:#{Settings[:user_name]} -state:rejected"
      get_stories(params)
    end

    def get_stories_to_assign(params={})
      params[:filter] =  "-state:accepted"
      get_stories(params)
    end

    def get_stories(params={})
      limit = @limit || 10
      page = params[:page] || 0
      offset = page*limit
      filter = params[:filter] || '-state=accepted'
      project.stories limit: limit, fields: STORY_FIELDS, auto_paginate: false, offset: offset, filter: filter
    end


    def get_member(query)
      member = project.memberships.select{ |m| m.person.name.downcase.start_with?(query.downcase) || m.person.initials.downcase == query.downcase }
      member.empty? ? nil : member.first
    end

    def find_member(query)
      project.memberships.detect do |m|
        m.person.name.downcase.start_with?(query.downcase) || m.person.initials.downcase == query.downcase
      end
    end

    def get_members
      project.memberships fields: ':default,person'
    end


    def mark_task_as(task, state)
      task.current_state = state
      task.save
    end

    def estimate_story(task, points)
      task.estimate = points
      task.save
    end

    def assign_story(story, owner)
      story.add_owner(owner)
      story.save
    end

    def add_label(task, label)
      task.add_label(label)
      task.save
    end

    def comment_task(task, comment)
      task = get_story(task.id)
      task.create_comment(text: comment)
    end

    def create_story(args)
      project.create_story(args)
    end

  end
end
