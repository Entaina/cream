# Pages wrapped in workspace Liquid templates run the workspace's own inline and
# third-party scripts (tag managers, consent banners, iframe resizing), so the
# global policy is only reported there instead of enforced.
module WorkspaceTemplateCsp
  extend ActiveSupport::Concern

  included do
    content_security_policy_report_only
  end
end
