require 'spec_helper'

describe AggregateProject do

  context "validations" do
    it { should validate_presence_of :name }
    it "has a valid Factory" do
      FactoryGirl.build(:aggregate_project).should be_valid
    end
  end

  let(:aggregate_project) { AggregateProject.new(name: "Aggregate Project") }

  it { should_not be_tracker_project }

  describe "callbacks" do
    subject { aggregate_project }

    describe "before_destroy" do
      let(:project) { projects(:socialitis) }
      let!(:aggregate_project) { FactoryGirl.create :aggregate_project, :projects => [project] }

      it "should remove its id from its projects" do
        project.aggregate_project_id.should_not be_nil
        aggregate_project.destroy
        project.reload.aggregate_project_id.should be_nil
      end
    end
  end

  describe "scopes" do
    describe "all_with_tags" do
      let(:results) { double(:results) }

      before do
        AggregateProject.should_receive(:enabled).and_return AggregateProject
        AggregateProject.should_receive(:joins).with(:projects).and_return AggregateProject
        AggregateProject.should_receive(:find_tagged_with).with("foo,bar", match_all: true).and_return results
      end

      subject { AggregateProject.all_with_tags("foo,bar") }

      it { should == results }
    end

    describe "with_statuses" do
      before do
        aggregate_project.save!
      end

      it "returns only projects with statuses" do
        projects = AggregateProject.with_statuses
        projects.length.should > 0

        projects.should_not include(aggregate_project)
        projects.each do |project|
          project.status.should_not be_nil
        end
      end
    end

    describe '.displayable' do
      subject { AggregateProject.displayable tags }

      let!(:tagged_project) { FactoryGirl.create :aggregate_project, :projects => [projects(:pivots)], enabled: true }
      let!(:untagged_project) { FactoryGirl.create :aggregate_project, :projects => [projects(:socialitis)], enabled: true }

      context "when supplying tags" do
        let(:tags) { "southeast, northwest" }

        it "should find tagged with tags" do
          scope = double
          AggregateProject.stub(:enabled) { scope }
          scope.should_receive(:all_with_tags).with(tags)
          subject
        end

        context "when displayable projects are tagged" do
          before do
            tagged_project.update_attributes(tag_list: tags)
            untagged_project.update_attributes(tag_list: [])
          end

          it "should return scoped projects" do
            subject.should include tagged_project
            subject.should_not include untagged_project
          end
        end

      end

      context "when not supplying tags" do
        let(:tags) { nil }

        it "should return scoped projects" do
          subject.should include tagged_project
          subject.should include untagged_project
        end
      end

    end


  end

  describe "#code" do
    let(:project) { AggregateProject.new(name: "My Cool Project", code: code) }
    subject { project.code }

    context "code set but empty" do
      let(:code) { "" }
      it { should == "myco" }
    end

    context "code not set" do
      let(:code) { nil }
      it { should == "myco" }
    end

    context "code is set" do
      let(:code) { "code" }
      it { should == "code" }
    end
  end

  describe "#red?" do
    it "should be red if one of its projects is red" do
      aggregate_project.should_not be_red
      aggregate_project.projects << projects(:red_currently_building)
      aggregate_project.should be_red
      aggregate_project.projects << projects(:green_currently_building)
      aggregate_project.should be_red
    end
  end

  describe "#green?" do
    it "should be green if all projects are green" do
      aggregate_project.should_not be_green
      aggregate_project.projects << projects(:green_currently_building)
      aggregate_project.should be_green
      aggregate_project.projects << projects(:pivots)
      aggregate_project.should be_green
    end
  end

  describe "#yellow?" do
    context "aggregate project doesn't have any projects" do
      subject { AggregateProject.new.yellow? }
      it { should be_false }
    end

    context "aggregate has one yellow project " do
      subject { AggregateProject.new(:projects => [
          Project.new.tap{|p| p.stub(yellow?: true)}]).yellow? }
      it { should be_true }
    end

    context "aggregate has one yellow and one red project " do
      subject do
        AggregateProject.new(:projects => [
          Project.new.tap{|p| p.stub(yellow?: true)},
          Project.new.tap{|p| p.stub(yellow?: false)}]).yellow?
      end
      it { should be_false }
    end
  end

  describe "#online?" do
    it "should not be online if any project not online" do
      aggregate_project.should_not be_online
      aggregate_project.projects << projects(:socialitis)
      aggregate_project.should be_online
      aggregate_project.projects << projects(:pivots)
      aggregate_project.should be_online
      aggregate_project.projects << projects(:offline)
      aggregate_project.should_not be_online
    end
  end

  describe '#status' do
    it "should return the last status of all the projects" do
      aggregate_project.projects << projects(:pivots)
      aggregate_project.projects << projects(:socialitis)
      aggregate_project.status.should == projects(:socialitis).latest_status
    end
  end

  describe '#building?' do
    it "should return the last status of all the projects" do
      aggregate_project.projects << projects(:pivots)
      aggregate_project.projects << projects(:socialitis)
      aggregate_project.should_not be_building
      aggregate_project.projects << projects(:green_currently_building)
      aggregate_project.should be_building
    end
  end

  describe '#recent_statuses' do
    it "should return the most recent statuses across projects" do
      aggregate_project.projects << projects(:pivots)
      aggregate_project.projects << projects(:socialitis)
      aggregate_project.recent_statuses.should include project_statuses(:pivots_status)
      aggregate_project.recent_statuses.should include project_statuses(:socialitis_status_green_01)
    end
  end

  describe "#statuses" do
    let(:aggregate_project) { aggregate_projects(:empty_aggregate) }

    it "return all latest_status of projects sorted by id, even if one of the project has no statuses" do
      aggregate_project.projects << projects(:socialitis)
      aggregate_project.projects << projects(:pivots)
      aggregate_project.projects << projects(:offline)
      aggregate_project.projects << Project.create(name: 'No status',
                                                   feed_url: 'http://ci.pivotallabs.com:3333/projects/pivots.rss')
      aggregate_project.reload.statuses.should == [projects(:pivots).latest_status,
                                                   projects(:socialitis).latest_status,
                                                   projects(:offline).latest_status,]
    end
  end

  describe "#red_since" do
    let(:aggregate_project) { aggregate_projects(:empty_aggregate) }

    it "returns #published_at for the red status after the most recent green status" do
      socialitis = projects(:socialitis)
      red_since = socialitis.red_since

      3.times do |i|
        socialitis.statuses.create!(success: false, build_id: i, published_at: Time.now + (i+1)*5.minutes )
      end

      aggregate_project.projects << socialitis

      aggregate_project.reload.red_since.should == red_since
    end

    it "should return nil if the project is currently green" do
      pivots = projects(:pivots)
      aggregate_project.projects << pivots
      pivots.should be_green

      pivots.red_since.should be_nil
    end

    it "should return the published_at of the first recorded status if the project has never been green" do
      project = projects(:never_green)
      aggregate_project.projects << project
      aggregate_project.statuses.detect(&:success?).should be_nil
      aggregate_project.red_since.should == project.statuses.last.published_at
    end

    it "should return nil if the project has no statuses" do
      @project = Project.new(:name => "my_project_foo", :feed_url => "http://foo.bar.com:3434/projects/mystuff/baz.rss")
      aggregate_project.projects << @project
      aggregate_project.red_since.should be_nil
    end
  end

  describe "#red_build_count" do
    it "should return the number of red builds since the last green build" do
      project = projects(:socialitis)
      aggregate_project.projects << project
      aggregate_project.red_build_count.should == 1

      project.statuses.create(success: false, build_id: 100)
      aggregate_project.red_build_count.should == 2
    end

    it "should return zero for a green project" do
      project = projects(:pivots)
      aggregate_project.projects << project
      aggregate_project.should be_green

      aggregate_project.red_build_count.should == 0
    end

    it "should not blow up for a project that has never been green" do
      project = projects(:never_green)
      aggregate_project.projects << project
      aggregate_project.red_build_count.should == aggregate_project.statuses.count
    end
  end

  describe "#breaking_build" do
    context "when a project does not have a published_at date" do
      it "should be ignored" do
        project = projects(:red_currently_building)
        other_project = projects(:socialitis)

        project.statuses.create(success: true, published_at: 1.day.ago, build_id: 100)
        status = project.statuses.create(success: false, published_at: Time.now, build_id: 102)

        other_project.statuses.create(success: true, published_at: 1.day.ago, build_id: 101)
        bad_status = other_project.statuses.create(success: false, published_at: nil, build_id: 99)
        aggregate_project.projects << project
        aggregate_project.projects << other_project
        aggregate_project.breaking_build.should == status
      end
    end

    context "when one of the projects has never been green" do
      let(:never_been_green_project) { projects(:red_currently_building) }
      let(:once_been_green_project) { projects(:socialitis) }

      before do
        once_been_green_project.statuses.create(success: true, published_at: 1.day.ago, build_id: 101)
        @earliest_red_build_status = never_been_green_project.statuses.create(success: false, published_at: 2.days.ago, build_id: 100)

        aggregate_project.projects << never_been_green_project
        aggregate_project.projects << once_been_green_project
      end

      it "should return the earliest red build status" do
        aggregate_project.breaking_build.should == @earliest_red_build_status
      end
    end
  end

  describe "#destroy" do
    it "should orphan its children projects" do
      aggregate_project = aggregate_projects(:internal_projects_aggregate)
      project = aggregate_project.projects.first
      aggregate_project.destroy
      Project.find(project.id).aggregate_project_id.should be(nil)
    end
  end

end
