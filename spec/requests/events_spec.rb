require 'spec_helper'

describe "Events" do
  
  describe "creation" do
    
    describe "failure" do
      it "should not create a new event" do
        lambda do
          user = Factory(:user, :email => 'purple@example.com', :confirmed_at => Time.now)
          visit new_user_session_path
          fill_in "Email",      :with => user.email
          fill_in "Password",   :with => user.password
          click_button
          controller.user_signed_in?.should be_true

          click_link 'Create New Event'
          response.should render_template('events/new')
          click_button
          response.should render_template('events/new')
          response.should have_selector('div#error_explanation')
        end.should_not change(Event, :count)
      end
    end
    
    describe "success" do
      it "should create a new event / edit an existing event / delete an existing event" do
        # log in
        user = Factory(:user, :email => 'green@example.com', :confirmed_at => Time.now)
        visit new_user_session_path
        fill_in "Email",      :with => user.email
        fill_in "Password",   :with => user.password
        click_button
        controller.user_signed_in?.should be_true

        # create event
        lambda do
          click_link 'Create New Event'
          response.should render_template('events/new')
          fill_in "Name",       :with => "Fancy Good Name"
          click_button
          response.should render_template('events/new')
          response.should have_selector('div.flash.notice', :content => 'Event was successfully created.')
        end.should change(Event, :count).by(1)

        # edit event
        event = Event.find_by_name("Fancy Good Name")
        click_link event.name
        response.should render_template('events/edit')
        fill_in "Name",       :with => "New Name"
        click_button
        response.should render_template('events/new')
        response.should have_selector('div.flash.notice', :content => 'Event was successfully updated.')
        event.reload
        event.name.should == 'New Name'

        # delete event - Can't figure out how to make this work with web-rat and javascript
        lambda do
          event.delete
        end.should change(Event, :count).by(-1)
        # https://webrat.lighthouseapp.com/projects/10503/tickets/365-allow-webrat-to-read-the-data-method-attribute
        # module Webrat
        #   class Link < Element
        #     def http_method
        #       if !@element["data-method"].blank?
        #         @element["data-method"]
        #       elsif !onclick.blank? && onclick.include?("f.submit()")
        #         http_method_from_js_form
        #       else
        #         :get
        #       end
        #     end
        #   end
        # end
        # event_id = event.id
        # lambda do
        #   click_link event.name
        #   response.should render_template('events/edit')
        #   controller.user_signed_in?.should be_true
        #   click_link 'Delete'
        #   controller.user_signed_in?.should be_true
        #   response.should render_template('events/new')
        #   response.should have_selector('div.flash.notice', :content => 'Event was successfully deleted.')
        # end.should change(Event, :count).by(-1)
        # Event.find_by_id(event_id).should be_nil
      end
    end
  end
end
