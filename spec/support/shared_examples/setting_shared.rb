shared_examples 'a setting' do |setting_key|
  before(:all) do
    @translation = I18n.t 'settings.'+setting_key
  end
  let(:setting) {Setting.where(:key => setting_key).first}
  let(:value) {'1'}

  it "should have translation" do
    expect(@translation).not_to be_start_with 'translation missing'
  end
  it "should show the setting" do
    within(".admin-container") do
      expect(page).to have_content(@translation)
    end
  end
  context "when the setting is edited" do
    before(:each) do
      within("#edit_setting_#{setting.id}") do
        fill_in("setting_value", :with => value)
        click_button "Save"
      end
      expect(page).to have_content("Settings successfully saved")
    end
    it "should update the form" do
      within("#edit_setting_#{setting.id}") do
        expect(find("#setting_value").value).to eq value
      end
    end
    it "should update the value in the database" do
      expect(setting.reload.value).to eq value
    end
  end
end

shared_examples 'only accepting numerical value' do |setting_key|
  let(:setting) {Setting.where(:key => setting_key).first}
  let(:value) {'foo'}
  context "when filled with non-numeric value" do
    before(:each) do
      within("#edit_setting_#{setting.id}") do
        fill_in("setting_value", :with => value)
        click_button "Save"
      end
      expect(page).to have_content("is not a number")
    end
    it "should fail when saving" do
      within("#edit_setting_#{setting.id}") do
        expect(find("#setting_value").value).not_to eq value
      end
    end
    it "should not update the value in the database" do
      expect(setting.value).not_to eq value
    end
  end
end