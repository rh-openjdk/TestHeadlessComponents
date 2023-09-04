public abstract class IncompatibleComponent extends AbstractComponent {

    @Override
    public boolean testComponent(TestArgumentParser parser){
        boolean err = false;
        try{
            SwingTestUtils.createComponent(this);
        } catch (java.awt.HeadlessException ex){
            if(parser.isJdkHeadless() || parser.isGraphicsEnvironmentHeadless()){
                System.out.println(SwingTestUtils.EXPECTED_ERROR_STRING);
            }
            else{
                System.out.println(SwingTestUtils.UNEXPECTED_EXCEPTION);
                ex.printStackTrace();
                err = true;
            }
        } catch (java.awt.AWTError e) {
	    if(parser.isDisplayInvalid()){
	        System.out.println(SwingTestUtils.EXPECTED_ERROR_STRING);
	    }
	    else{
	        System.out.println(SwingTestUtils.UNEXPECTED_EXCEPTION);
                e.printStackTrace();
                err = true;
	    }
	} catch (java.lang.NoClassDefFoundError e) {
	    if (!parser.isGraphicsEnvironmentHeadless() && (parser.isDisplayInvalid() || parser.isJdkHeadless())){
	        System.out.println(SwingTestUtils.EXPECTED_ERROR_STRING);
	    } else {
                err = SwingTestUtils.printMessageErrorFound(e);
            }
	} catch (java.lang.UnsatisfiedLinkError e) {
	    if(!parser.isGraphicsEnvironmentHeadless() && parser.isJdkHeadless()){
	        System.out.println(SwingTestUtils.EXPECTED_ERROR_STRING);
	    } else {
	        err = SwingTestUtils.printMessageErrorFound(e);
	    }
	
	} 
	catch (Error e) {
            err = SwingTestUtils.printMessageErrorFound(e);
        } catch (Exception ex) {
            System.err.println(SwingTestUtils.UNEXPECTED_EXCEPTION);
            ex.printStackTrace();
            err = true;
        }
        return err;

    }
}
