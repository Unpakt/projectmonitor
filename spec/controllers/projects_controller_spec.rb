require 'spec_helper'
require 'time'

describe ProjectsController do
  describe "without a logged in user" do
    describe "status" do
      let(:project) { projects(:socialitis) }
      before { get :status, :id => project.id, :tiles_count => 8 }

      it "should render dashboards/_project" do
        response.should render_template("dashboards/_project")
      end
    end
  end

  describe "with a logged in user" do
    before do
      sign_in FactoryGirl.create(:user)
    end

    context "when nested under an aggregate project" do
      it "should scope by aggregate_project_id" do
        Project.should_receive(:with_aggregate_project).with('1')
        get :index, aggregate_project_id: 1
      end
    end

    describe "create" do
      context "when the project was successfully created" do
        subject do
          post :create, :project => {
            :name => 'name',
            :type => JenkinsProject.name,
            :jenkins_base_url => 'http://www.example.com',
            :jenkins_build_name => 'example'
          }
        end

        it "should create a project of the correct type" do
          lambda { subject }.should change(JenkinsProject, :count).by(1)
        end

        it "should set the flash" do
          subject
          flash[:notice].should == 'Project was successfully created.'
        end

        it { should redirect_to edit_configuration_path }
      end

      context "when the project was not successfully created" do
        before { post :create, :project => { :name => nil, :type => JenkinsProject.name} }
        it { should render_template :new }
      end
    end

    describe "update" do
      context "when the project was successfully updated" do
        before { put :update, :id => projects(:jenkins_project), :project => { :name => "new name" } }

        it "should set the flash" do
          flash[:notice].should == 'Project was successfully updated.'
        end

        it { should redirect_to edit_configuration_path }
      end

      context "when the project was not successfully updated" do
        before { put :update, :id => projects(:jenkins_project), :project => { :name => nil } }
        it { should render_template :edit }
      end
    end

    describe "destroy" do
      subject { delete :destroy, :id => projects(:jenkins_project) }

      it "should destroy the project" do
        lambda { subject }.should change(JenkinsProject, :count).by(-1)
      end

      it "should set the flash" do
        subject
        flash[:notice].should == 'Project was successfully destroyed.'
      end

      it { should redirect_to edit_configuration_path }
    end

    describe "#validate_tracker_project" do
      let(:status) { :ok }

      subject { response }

      before do
        TrackerProjectValidator.stub(:validate).and_return status
        post :validate_tracker_project, { auth_token: "12354", project_id: "98765" }
      end

      it { should be_success }
    end

    describe "#validate_build_info" do
      subject { response }

      before do
        JenkinsProject.should_receive(:new).and_return(project)
        ProjectUpdater.should_receive(:update).with(project)
        post :validate_build_info, :project => {:type => "JenkinsProject"}
      end

      context "project is online" do
        let(:project) { double(:project, online: true) }

        it { should be_success }
      end

      context "project is offline" do
        let(:project) { double(:project, online: false) }

        its(:status) { should == 403 }
      end
    end

    describe "#update_projects" do
      context "The queue is empty" do
        before do
          Delayed::Job.should_receive(:count) { stub(zero?: true) }
          StatusFetcher.should_receive(:fetch_all)
        end
        it "should fetch statuses" do
          post :update_projects, { auth_token: "12354" }
          response.should be_success
        end
      end
      context "The queue is not empty" do
        before do
          Delayed::Job.should_receive(:count) { stub(zero?: false) }
          StatusFetcher.should_not_receive(:fetch_all)
        end
        it "should fetch statuses" do
          post :update_projects, { auth_token: "12354" }
          response.response_code.should == 409
        end
      end
    end

  end
end
