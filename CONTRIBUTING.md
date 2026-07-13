Contributing
============

Contributions are welcome from the community, and there are many ways to plug in.

### Using GitLab Issues
**Have a question about the repository, want to suggest a feature request, or notice a bug?** Please visit the 
[issues page](https://code.usgs.gov/wma/vizlab/storm-flood-viz/-/issues) to document your question or provide context for your suggestion/error report. Before creating a new issue, please take a moment to search
and make sure a similar issue does not already exist. If one does exist, you
can comment (most simply even with just a `:+1:`) to show your support for that
issue.

### Contributing directly to the repository

This team uses a fork-and-merge flow to contribute code or files to the repository and relies heavily on the program *git* for version control. 

#### Fork, clone, create a branch, and commit

Steps to set yourself up to contribute to the repository:

- [ ] Log in to your GitLab account using single sign-on
- [ ] [Configure your SSH key with GitLab](https://docs.gitlab.com/ee/user/ssh.html)
- [ ] Fork the repository to your GitLab workspace
- [ ] Clone your fork of the repository to your local folder of choice using the SSH URL and the following commands in a terminal or command line:`git clone git@code.usgs.gov:[your user name]/storm-flood-viz.git' 
- [ ] Navigate to the new repository folder and launch the .Rproj file to open an RStudio session
- [ ] In the RStudio terminal, check the branch you are currently in by entering: `git branch` If you are not in the `main` repository, enter: `git switch main`
- [ ] From the `main` branch in the repository, create a new branch for your changes (change the text [new branch name] to a simple descriptor of your contributions): `git checkout -b [new branch name]`
- [ ] Enter `git branch` again to ensure you've switched to YOUR new branch
- [ ] Finally **WHILE ON VPN** enter `git push origin [new branch name]` to push your new branch to the remote repository

You are now ready to make improvements!

As you make edits to your branch, take the following actions to keep track of and commit your changes:

- [ ] Enter `git status` to view the files that have been changed, and which are/are not being tracked.
- [ ] To add your changed file(s) to the tracked files list (needed to commit those changes), enter `git add [name of changed file]`, then enter `git status` to verify you have added the files correctly.
- [ ] When you are ready to commit to your branch, with all the changed files added to the tracked files list, enter `git commit -m "[description of your commit]"` Keep the description succinct.
- [ ] If you realize you made a mistake in one of your commits and want to walk it back, enter `git log` to find the commit ID (first column of the returned info, a mix of letters and numbers), and then `git revert [commit ID]` to create a new commit that removes the changes made in the "bad" commit  
- [ ] Your changes have now been committed **locally**, but to push those changes to your remote branch on GitLab, enter `git push origin [new branch name]` Remember: **You need to be on VPN**

#### Make a merge request

Once you're ready to combine your changes on your fork and branch with the canonical upstream repository, it's time to create a merge request on GitLab. 

**Rule:** All merge requests must be reviewed and approved before performing the merge.

**Note about rule:** Because every merge request must be reviewed by a human with only so much bandwidth, please be empathetic when creating branches, making commits, and requesting merges. If you have big plans for the repository, great! But please implement them incrementally, so reviewers do not get lost in the massive changes to the code or files. GitLab, among many others, have great [articles](https://about.gitlab.com/blog/2021/03/18/iteration-and-code-review/) on the optimal merge request size.

Basic steps (all on GitLab):

- [ ] Navigate to your remote forked repository and click on the menu item Merge Requests.
- [ ] Create a merge request between your remote forked repository branch and the canonical (upstream) main branch
- [ ] Write a clear, concise description of the purpose of your pull request. Please be more specific than "bug fix" or "add feature". What does the code do? Why is it important? Give your audience something to work off of when they begin reviewing your commits and code
- [ ] Select a reviewer (most likely Elmera Azadpour) to review your merge request
- [ ] Maintain your discussion with your reviewer(s) in the merge request through messages below the initial merge request description. This makes it easier to dig up logic/discussions if questions come up later about the change.
- [ ] Once the reviewer approves your changes, merge your commits into the canonical main and repeat! Nicely done. 

#### Errors and bugs

If you make a mistake or find an error, that's OK! The superpowers of Git and GitLab give us the ability to revert commits and merges...breadcrumbs are left all along the way. If you notice an error that was missed after a review, please submit an issue, and the team can decide the best way to respond. 


