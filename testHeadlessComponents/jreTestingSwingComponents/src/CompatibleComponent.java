public abstract class CompatibleComponent extends AbstractComponent {
	
    @Override
    public boolean testComponent(TestArgumentParser parser){
	boolean err = false;
        try {
            SwingTestUtils.createComponent(this);
        } catch (java.lang.NoClassDefFoundError expectedError) {
            if (parser.isJdkHeadless() && !parser.isGraphicsEnvironmentHeadless()) {
                if (parser.isDisplayInvalid() || parser.isDisplayValid()) {
                System.out.println(SwingTestUtils.EXPECTED_ERROR_STRING);
                } else {
                    err = SwingTestUtils.printMessageErrorFound(expectedError);
                }
            } else if ((parser.isJdkSdk() || parser.isJdkJre())
                    && !parser.isGraphicsEnvironmentHeadless()) {
                if (parser.isDisplayInvalid()) {
                    System.out.println(SwingTestUtils.EXPECTED_ERROR_STRING);
                } else {
                   err = SwingTestUtils.printMessageErrorFound(expectedError);
                }
            } else {
                 err = SwingTestUtils.printMessageErrorFound(expectedError);
            }
        } catch (java.lang.UnsatisfiedLinkError expectErr) {
           if (parser.isJdkHeadless() && !parser.isGraphicsEnvironmentHeadless()) {
                if (parser.isDisplayInvalid() || parser.isDisplayValid()) {
                    System.out.println(SwingTestUtils.EXPECTED_ERROR_STRING);
                } else {
                    err = SwingTestUtils.printMessageErrorFound(expectErr);
                }
            } else {
                err = SwingTestUtils.printMessageErrorFound(expectErr);
            }
        } catch (java.awt.AWTError expectErr) {
            if (!parser.isGraphicsEnvironmentHeadless()) {
                if (parser.isDisplayInvalid()) {
                    System.out.println(SwingTestUtils.EXPECTED_ERROR_STRING);
                } else {
                    err = SwingTestUtils.printMessageErrorFound(expectErr);
                }
            } else {
                err = SwingTestUtils.printMessageErrorFound(expectErr);
            }
        } catch (Error e) {
            err = SwingTestUtils.printMessageErrorFound(e);
        } catch (Exception ex) {
            System.err.println(SwingTestUtils.UNEXPECTED_EXCEPTION);
            ex.printStackTrace();
            err = true;
        }
        return err;
	}
}
