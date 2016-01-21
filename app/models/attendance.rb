class Attendance < ActiveRecord::Base
  belongs_to :event
  belongs_to :user
  belongs_to :membership

  has_one :group, through: :event
  has_one :cohort, through: :event

  def date
    self.event.date.strftime("%a, %m/%d/%y")
  end

  def self.statuses
    {
      nil => "n/a",
      0 => "Absent",
      1 => "Tardy",
      2 => "Present"
    }
  end

  def status_english
    return Attendance.statuses[self.status]
  end
end
